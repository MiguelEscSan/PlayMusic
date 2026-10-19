import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/search/presentation/search_history_providers.dart';

import '../domain/fakes/fake_feature_repositories.dart';

void main() {
  late FakeSearchHistoryRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSearchHistoryRepository(['b', 'a']);
    container = ProviderContainer(
      overrides: [searchHistoryRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(recentSearchesProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  Future<List<String>> recent() =>
      container.read(recentSearchesProvider.future);

  RecentSearchesNotifier notifier() =>
      container.read(recentSearchesProvider.notifier);

  test('loads the recent searches', () async {
    expect(await recent(), ['b', 'a']);
  });

  test('record refreshes the list', () async {
    await recent();
    expect(await notifier().record('c'), const Ok(unit));
    expect(await recent(), ['c', 'b', 'a']);
  });

  test('remove refreshes the list', () async {
    await recent();
    expect(await notifier().remove('b'), const Ok(unit));
    expect(await recent(), ['a']);
  });

  test('clear refreshes the list', () async {
    await recent();
    expect(await notifier().clear(), const Ok(unit));
    expect(await recent(), isEmpty);
  });

  test('a failed write is returned as Err', () async {
    await recent();
    const failure = DatabaseFailure('disk full');
    repo.failure = failure;
    expect(await notifier().record('c'), const Err<Unit>(failure));
  });
}
