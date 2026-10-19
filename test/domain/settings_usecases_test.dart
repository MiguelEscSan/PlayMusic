import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/settings/domain/usecases/get_download_only_wifi_use_case.dart';
import 'package:koda/features/settings/domain/usecases/get_radio_enabled_use_case.dart';
import 'package:koda/features/settings/domain/usecases/set_download_only_wifi_use_case.dart';
import 'package:koda/features/settings/domain/usecases/set_radio_enabled_use_case.dart';

import 'fakes/fake_feature_repositories.dart';

const _failure = DatabaseFailure('disk full');

void main() {
  late FakeSettingsRepository settings;

  setUp(() => settings = FakeSettingsRepository());

  group('GetRadioEnabledUseCase', () {
    test('returns the stored value', () async {
      settings.radioEnabled = false;
      expect(await GetRadioEnabledUseCase(settings)(), const Ok(false));
    });

    test('propagates the failure', () async {
      settings.failure = _failure;
      expect(
        await GetRadioEnabledUseCase(settings)(),
        const Err<bool>(_failure),
      );
    });
  });

  group('SetRadioEnabledUseCase', () {
    test('stores the value', () async {
      expect(await SetRadioEnabledUseCase(settings)(false), const Ok(unit));
      expect(settings.radioEnabled, isFalse);
    });

    test('propagates the failure', () async {
      settings.failure = _failure;
      expect(
        await SetRadioEnabledUseCase(settings)(false),
        const Err<Unit>(_failure),
      );
    });
  });

  group('GetDownloadOnlyWifiUseCase', () {
    test('returns the stored value', () async {
      settings.downloadOnlyWifi = true;
      expect(await GetDownloadOnlyWifiUseCase(settings)(), const Ok(true));
    });

    test('propagates the failure', () async {
      settings.failure = _failure;
      expect(
        await GetDownloadOnlyWifiUseCase(settings)(),
        const Err<bool>(_failure),
      );
    });
  });

  group('SetDownloadOnlyWifiUseCase', () {
    test('stores the value', () async {
      expect(await SetDownloadOnlyWifiUseCase(settings)(true), const Ok(unit));
      expect(settings.downloadOnlyWifi, isTrue);
    });

    test('propagates the failure', () async {
      settings.failure = _failure;
      expect(
        await SetDownloadOnlyWifiUseCase(settings)(true),
        const Err<Unit>(_failure),
      );
    });
  });
}
