import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/domain/sources/i_track_search.dart';
import 'package:sponify/features/search/domain/suggestion_source.dart';
import 'package:sponify/features/search/domain/usecases/clear_recent_searches_use_case.dart';
import 'package:sponify/features/search/domain/usecases/get_recent_searches_use_case.dart';
import 'package:sponify/features/search/domain/usecases/get_suggestions_use_case.dart';
import 'package:sponify/features/search/domain/usecases/record_search_use_case.dart';
import 'package:sponify/features/search/domain/usecases/remove_recent_search_use_case.dart';
import 'package:sponify/features/search/domain/usecases/search_songs_use_case.dart';

import 'fakes/fake_feature_repositories.dart';

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

const _failure = DatabaseFailure('disk full');

/// Origen falso: [pages] se sirven en orden; [error] se lanza si no es null.
class _FakeSource implements ITrackSearch {
  _FakeSource(this.pages);

  final List<List<Song>> pages;
  Object? error;
  Object? loadMoreError;
  final queries = <String>[];

  @override
  Future<SearchPage> search(String query) async {
    queries.add(query);
    if (error case final e?) throw e;
    return _page(0);
  }

  SearchPage _page(int i) => SearchPage(
    pages[i],
    i + 1 < pages.length
        ? () async {
            if (loadMoreError case final e?) throw e;
            return _page(i + 1);
          }
        : null,
  );
}

class _FakeSuggestions implements SuggestionSource {
  Object? error;

  @override
  Future<List<String>> suggestions(String query) async {
    if (error case final e?) throw e;
    return ['$query uno', '$query dos'];
  }
}

void main() {
  group('SearchSongsUseCase', () {
    test('returns the first page and pages through loadMore', () async {
      final source = _FakeSource([
        [_song('a')],
        [_song('b')],
      ]);
      final first = (await SearchSongsUseCase(source)('rosalia')).valueOrNull!;
      expect(source.queries, ['rosalia']);
      expect(first.songs, [_song('a')]);
      expect(first.loadMore, isNotNull);

      final second = (await first.loadMore!()).valueOrNull!;
      expect(second.songs, [_song('b')]);
      expect(second.loadMore, isNull);
    });

    test('an offline error becomes a NetworkFailure', () async {
      final source = _FakeSource([[]])
        ..error = Exception('SocketException: Failed host lookup');
      final failure = (await SearchSongsUseCase(source)('x')).failureOrNull;
      expect(failure, isA<NetworkFailure>());
    });

    test('any other error becomes an UnexpectedFailure', () async {
      final source = _FakeSource([[]])..error = StateError('boom');
      final failure = (await SearchSongsUseCase(source)('x')).failureOrNull;
      expect(failure, isA<UnexpectedFailure>());
    });

    test('a failing loadMore returns Err instead of throwing', () async {
      final source = _FakeSource([
        [_song('a')],
        [_song('b')],
      ])..loadMoreError = Exception('ClientException');
      final first = (await SearchSongsUseCase(source)('x')).valueOrNull!;
      expect((await first.loadMore!()).failureOrNull, isA<NetworkFailure>());
    });
  });

  group('GetSuggestionsUseCase', () {
    test('returns the suggestions', () async {
      expect(
        (await GetSuggestionsUseCase(_FakeSuggestions())('ro')).valueOrNull,
        ['ro uno', 'ro dos'],
      );
    });

    test('an error becomes Err', () async {
      final source = _FakeSuggestions()..error = Exception('sin red');
      expect((await GetSuggestionsUseCase(source)('ro')).isErr, isTrue);
    });
  });

  group('recent searches', () {
    late FakeSearchHistoryRepository history;

    setUp(() => history = FakeSearchHistoryRepository(['b', 'a']));

    test('GetRecentSearchesUseCase returns the latest first', () async {
      expect((await GetRecentSearchesUseCase(history)()).valueOrNull, [
        'b',
        'a',
      ]);
    });

    test('RecordSearchUseCase records the query', () async {
      expect(await RecordSearchUseCase(history)('a'), const Ok(unit));
      expect(history.queries, ['a', 'b']);
    });

    test('RemoveRecentSearchUseCase removes one query', () async {
      expect(await RemoveRecentSearchUseCase(history)('b'), const Ok(unit));
      expect(history.queries, ['a']);
    });

    test('ClearRecentSearchesUseCase removes all of them', () async {
      expect(await ClearRecentSearchesUseCase(history)(), const Ok(unit));
      expect(history.queries, isEmpty);
    });

    test('failures are propagated', () async {
      history.failure = _failure;
      expect(
        (await GetRecentSearchesUseCase(history)()).failureOrNull,
        _failure,
      );
      expect((await RecordSearchUseCase(history)('x')).failureOrNull, _failure);
      expect(
        (await RemoveRecentSearchUseCase(history)('x')).failureOrNull,
        _failure,
      );
      expect(
        (await ClearRecentSearchesUseCase(history)()).failureOrNull,
        _failure,
      );
    });
  });
}
