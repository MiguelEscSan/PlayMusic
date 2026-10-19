import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/domain/history_events.dart';
import 'package:koda/features/history/domain/usecases/clear_history_use_case.dart';
import 'package:koda/features/history/domain/usecases/get_recent_songs_use_case.dart';
import 'package:koda/features/history/domain/usecases/get_top_songs_use_case.dart';
import 'package:koda/features/history/domain/usecases/watch_history_changed_use_case.dart';

import 'fakes/fake_feature_repositories.dart';

Song _song(String id) => Song(
  id: id,
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

const _failure = DatabaseFailure('disk full');

void main() {
  late FakeHistoryRepository history;
  late HistoryEvents events;

  setUp(() {
    history = FakeHistoryRepository(recent: [_song('r')], top: [_song('t')]);
    events = HistoryEvents();
  });

  tearDown(() => events.dispose());

  group('GetRecentSongsUseCase', () {
    test('returns the recent songs', () async {
      expect((await GetRecentSongsUseCase(history)()).valueOrNull, [
        _song('r'),
      ]);
    });

    test('propagates the failure', () async {
      history.failure = _failure;
      expect((await GetRecentSongsUseCase(history)()).failureOrNull, _failure);
    });
  });

  group('GetTopSongsUseCase', () {
    test('returns the most played songs', () async {
      expect((await GetTopSongsUseCase(history)()).valueOrNull, [_song('t')]);
    });

    test('propagates the failure', () async {
      history.failure = _failure;
      expect((await GetTopSongsUseCase(history)()).failureOrNull, _failure);
    });
  });

  group('ClearHistoryUseCase', () {
    test('clears the history and announces the change', () async {
      final changed = events.changes.first;
      expect(await ClearHistoryUseCase(history, events)(), const Ok(unit));
      expect(history.clearCalls, 1);
      await changed;
    });

    test('a failure is returned and not announced', () async {
      history.failure = _failure;
      var announced = false;
      final sub = events.changes.listen((_) => announced = true);
      expect(
        await ClearHistoryUseCase(history, events)(),
        const Err<Unit>(_failure),
      );
      await pumpEventQueue();
      expect(announced, isFalse);
      await sub.cancel();
    });
  });

  group('WatchHistoryChangedUseCase', () {
    test('emits every announced change', () async {
      final received = <Unit>[];
      final sub = WatchHistoryChangedUseCase(events)().listen(received.add);
      events.announce();
      events.announce();
      await pumpEventQueue();
      expect(received, hasLength(2));
      await sub.cancel();
    });
  });
}
