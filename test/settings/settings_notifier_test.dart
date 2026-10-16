import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/settings/presentation/settings_providers.dart';

import '../domain/fakes/fake_feature_repositories.dart';

const _failure = DatabaseFailure('disk full');

void main() {
  late FakeSettingsRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSettingsRepository()
      ..radioEnabled = false
      ..downloadOnlyWifi = true;
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  Future<AppSettings> load() => container.read(settingsProvider.future);

  test('loads the stored settings', () async {
    final settings = await load();
    expect(settings.radioEnabled, isFalse);
    expect(settings.downloadOnlyWifi, isTrue);
  });

  test('setRadioEnabled updates the state and persists it', () async {
    await load();
    final result = await container
        .read(settingsProvider.notifier)
        .setRadioEnabled(true);
    expect(result, const Ok(unit));
    expect(repo.radioEnabled, isTrue);
    expect(container.read(settingsProvider).value!.radioEnabled, isTrue);
  });

  test('setDownloadOnlyWifi updates the state and persists it', () async {
    await load();
    final result = await container
        .read(settingsProvider.notifier)
        .setDownloadOnlyWifi(false);
    expect(result, const Ok(unit));
    expect(repo.downloadOnlyWifi, isFalse);
    expect(container.read(settingsProvider).value!.downloadOnlyWifi, isFalse);
  });

  test('a failed save rolls the state back and returns Err', () async {
    await load();
    repo.failure = _failure;
    final notifier = container.read(settingsProvider.notifier);

    expect(await notifier.setRadioEnabled(true), const Err<Unit>(_failure));
    expect(
      await notifier.setDownloadOnlyWifi(false),
      const Err<Unit>(_failure),
    );

    final state = container.read(settingsProvider).value!;
    expect(state.radioEnabled, isFalse);
    expect(state.downloadOnlyWifi, isTrue);
  });

  test('a failed load surfaces the typed failure', () async {
    repo.failure = _failure;
    await expectLater(load(), throwsA(_failure));
  });
}
