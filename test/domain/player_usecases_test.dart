import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/player_rules.dart';
import 'package:koda/features/player/domain/usecases/add_to_queue_use_case.dart';
import 'package:koda/features/player/domain/usecases/cycle_repeat_mode_use_case.dart';
import 'package:koda/features/player/domain/usecases/move_in_queue_use_case.dart';
import 'package:koda/features/player/domain/usecases/pause_playback_use_case.dart';
import 'package:koda/features/player/domain/usecases/play_next_use_case.dart';
import 'package:koda/features/player/domain/usecases/play_queue_use_case.dart';
import 'package:koda/features/player/domain/usecases/play_shuffled_use_case.dart';
import 'package:koda/features/player/domain/usecases/remove_from_queue_use_case.dart';
import 'package:koda/features/player/domain/usecases/seek_use_case.dart';
import 'package:koda/features/player/domain/usecases/set_stop_after_current_use_case.dart';
import 'package:koda/features/player/domain/usecases/skip_to_next_use_case.dart';
import 'package:koda/features/player/domain/usecases/skip_to_previous_song_use_case.dart';
import 'package:koda/features/player/domain/usecases/skip_to_previous_use_case.dart';
import 'package:koda/features/player/domain/usecases/skip_to_queue_index_use_case.dart';
import 'package:koda/features/player/domain/usecases/toggle_play_pause_use_case.dart';
import 'package:koda/features/player/domain/usecases/toggle_shuffle_use_case.dart';
import 'package:koda/features/player/domain/usecases/watch_player_position_use_case.dart';
import 'package:koda/features/player/domain/usecases/watch_player_snapshot_use_case.dart';

import 'fakes/fake_audio_player_service.dart';
import 'fakes/fake_song_repository.dart';

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Guarda dando a cada canción el id `db-<sourceId>` y apunta el orden en
/// el registro compartido.
class _SavingSongRepository extends FakeSongRepository {
  _SavingSongRepository(this.log);

  final List<String> log;

  @override
  Future<Result<Song>> save(Song song) async {
    saveCalls.add(song);
    log.add('save(${song.sourceId})');
    return saveResult ?? Ok(song.copyWith(id: 'db-${song.sourceId}'));
  }
}

const _dbFailure = DatabaseFailure('disk full');

void main() {
  late FakeAudioPlayerService audio;
  late List<String> log;
  late _SavingSongRepository songs;

  setUp(() {
    log = [];
    audio = FakeAudioPlayerService()..log = log;
    songs = _SavingSongRepository(log)..saveResult = null;
  });

  group('player rules', () {
    test('repeat cycles off -> all -> one -> off', () {
      expect(nextRepeatMode(PlayerRepeatMode.off), PlayerRepeatMode.all);
      expect(nextRepeatMode(PlayerRepeatMode.all), PlayerRepeatMode.one);
      expect(nextRepeatMode(PlayerRepeatMode.one), PlayerRepeatMode.off);
    });

    test('previous song index is current - 1, null at the start', () {
      expect(previousSongIndex(const PlayerSnapshot(currentIndex: 3)), 2);
      expect(previousSongIndex(const PlayerSnapshot(currentIndex: 0)), isNull);
      expect(previousSongIndex(const PlayerSnapshot()), isNull);
    });
  });

  group('PlayQueueUseCase', () {
    test('persists every song before playing the saved copies', () async {
      final result = await PlayQueueUseCase(songs, audio)([
        _song('a'),
        _song('b'),
      ], 1);

      expect(result, const Ok(unit));
      expect(log, ['save(a)', 'save(b)', 'audio.playQueue([db-a,db-b], 1)']);
    });

    test('does not play when a song cannot be saved', () async {
      songs.saveResult = const Err(_dbFailure);
      final result = await PlayQueueUseCase(songs, audio)([_song('a')], 0);

      expect(result.failureOrNull, _dbFailure);
      expect(audio.calls, isEmpty);
    });

    test('returns PlaybackFailure when the player throws', () async {
      audio.error = StateError('boom');
      final result = await PlayQueueUseCase(songs, audio)([_song('a')], 0);

      expect(result.failureOrNull, isA<PlaybackFailure>());
    });
  });

  group('PlayShuffledUseCase', () {
    test('enables shuffle, persists, then plays from the start', () async {
      final result = await PlayShuffledUseCase(songs, audio)([
        _song('a'),
        _song('b'),
      ]);

      expect(result, const Ok(unit));
      expect(log, [
        'audio.setShuffle(true)',
        'save(a)',
        'save(b)',
        'audio.playQueue([db-a,db-b], 0)',
      ]);
    });

    test('an empty list does nothing', () async {
      expect(await PlayShuffledUseCase(songs, audio)([]), const Ok(unit));
      expect(log, isEmpty);
    });

    test('returns PlaybackFailure when the player throws', () async {
      audio.error = StateError('boom');
      final result = await PlayShuffledUseCase(songs, audio)([_song('a')]);
      expect(result.failureOrNull, isA<PlaybackFailure>());
    });
  });

  group('PlayNextUseCase / AddToQueueUseCase', () {
    test('play next persists first', () async {
      expect(await PlayNextUseCase(songs, audio)(_song('a')), const Ok(unit));
      expect(log, ['save(a)', 'audio.playNext(db-a)']);
    });

    test('add to queue persists first', () async {
      expect(await AddToQueueUseCase(songs, audio)(_song('a')), const Ok(unit));
      expect(log, ['save(a)', 'audio.addToQueue(db-a)']);
    });

    test('a save failure is returned and nothing is queued', () async {
      songs.saveResult = const Err(_dbFailure);
      expect(
        (await PlayNextUseCase(songs, audio)(_song('a'))).failureOrNull,
        _dbFailure,
      );
      expect(
        (await AddToQueueUseCase(songs, audio)(_song('a'))).failureOrNull,
        _dbFailure,
      );
      expect(audio.calls, isEmpty);
    });

    test('a player error becomes PlaybackFailure', () async {
      audio.error = StateError('boom');
      expect(
        (await PlayNextUseCase(songs, audio)(_song('a'))).failureOrNull,
        isA<PlaybackFailure>(),
      );
      expect(
        (await AddToQueueUseCase(songs, audio)(_song('a'))).failureOrNull,
        isA<PlaybackFailure>(),
      );
    });
  });

  group('transport and queue', () {
    const snapshot = PlayerSnapshot(
      currentIndex: 2,
      repeatMode: PlayerRepeatMode.all,
      shuffleEnabled: true,
    );

    final cases = <String, (Future<Result<Unit>> Function(), String)>{
      'TogglePlayPause': (
        () => TogglePlayPauseUseCase(audio)(),
        'togglePlayPause',
      ),
      'SkipToNext': (() => SkipToNextUseCase(audio)(), 'skipToNext'),
      'SkipToPrevious': (
        () => SkipToPreviousUseCase(audio)(),
        'skipToPrevious',
      ),
      'SkipToPreviousSong': (
        () => SkipToPreviousSongUseCase(audio)(snapshot),
        'skipToIndex(1)',
      ),
      'SkipToQueueIndex': (
        () => SkipToQueueIndexUseCase(audio)(4),
        'skipToIndex(4)',
      ),
      'Seek': (
        () => SeekUseCase(audio)(const Duration(seconds: 3)),
        'seek(3000)',
      ),
      'ToggleShuffle': (
        () => ToggleShuffleUseCase(audio)(snapshot),
        'setShuffle(false)',
      ),
      'CycleRepeatMode': (
        () => CycleRepeatModeUseCase(audio)(snapshot),
        'setRepeat(one)',
      ),
      'MoveInQueue': (
        () => MoveInQueueUseCase(audio)(1, 3),
        'moveInQueue(1, 3)',
      ),
      'RemoveFromQueue': (
        () => RemoveFromQueueUseCase(audio)(2),
        'removeFromQueue(2)',
      ),
      'PausePlayback': (() => PausePlaybackUseCase(audio)(), 'pause'),
      'SetStopAfterCurrent': (
        () => SetStopAfterCurrentUseCase(audio)(true),
        'setStopAfterCurrent(true)',
      ),
    };

    for (final MapEntry(key: name, value: (run, expected)) in cases.entries) {
      test('$name calls the player and returns Ok', () async {
        expect(await run(), const Ok(unit));
        expect(audio.calls, [expected]);
      });

      test('$name returns PlaybackFailure when the player throws', () async {
        audio.error = StateError('boom');
        expect((await run()).failureOrNull, isA<PlaybackFailure>());
      });
    }

    test('SkipToPreviousSong does nothing at the start of the queue', () async {
      final result = await SkipToPreviousSongUseCase(
        audio,
      )(const PlayerSnapshot(currentIndex: 0));
      expect(result, const Ok(unit));
      expect(audio.calls, isEmpty);
    });

    test('ToggleShuffle enables it when it is off', () async {
      await ToggleShuffleUseCase(audio)(const PlayerSnapshot());
      expect(audio.calls, ['setShuffle(true)']);
    });

    test('CycleRepeatMode goes from off to all', () async {
      await CycleRepeatModeUseCase(audio)(const PlayerSnapshot());
      expect(audio.calls, ['setRepeat(all)']);
    });
  });

  group('watch use cases', () {
    test('WatchPlayerSnapshot forwards the player snapshots', () async {
      const s = PlayerSnapshot(currentIndex: 1);
      final next = WatchPlayerSnapshotUseCase(audio)().first;
      audio.snapshotController.add(s);
      expect(await next, same(s));
    });

    test('WatchPlayerPosition forwards the player position', () async {
      final next = WatchPlayerPositionUseCase(audio)().first;
      audio.positionController.add(const Duration(seconds: 7));
      expect(await next, const Duration(seconds: 7));
    });
  });
}
