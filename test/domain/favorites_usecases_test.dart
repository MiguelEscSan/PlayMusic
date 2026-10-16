import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/favorites/domain/i_liked_playlist_sync.dart';
import 'package:sponify/features/favorites/domain/usecases/get_liked_songs_use_case.dart';
import 'package:sponify/features/favorites/domain/usecases/toggle_like_use_case.dart';

import 'fakes/fake_services.dart';
import 'fakes/fake_song_repository.dart';

const _song = Song(
  id: '',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt1',
);

const _saved = Song(
  id: 's1',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt1',
);

void main() {
  late FakeSongRepository songs;

  setUp(() => songs = FakeSongRepository());

  group('GetLikedSongsUseCase', () {
    test('returns the liked songs', () async {
      songs.getLikedResult = const Ok([_saved]);
      expect((await GetLikedSongsUseCase(songs)()).valueOrNull, [_saved]);
    });

    test('propagates the failure unchanged', () async {
      const failure = DatabaseFailure('locked');
      songs.getLikedResult = const Err(failure);
      expect((await GetLikedSongsUseCase(songs)()).failureOrNull, failure);
    });
  });

  group('ToggleLikeUseCase', () {
    final clock = DateTime(2026, 10, 16, 12);
    late FakeLikedPlaylistSync sync;
    late ToggleLikeUseCase toggle;

    setUp(() {
      sync = FakeLikedPlaylistSync();
      songs.saveResult = const Ok(_saved);
      toggle = ToggleLikeUseCase(songs, sync, now: () => clock);
    });

    test('saves, likes with the clock and syncs "Me encanta"', () async {
      final result = await toggle(_song);

      expect(songs.saveCalls, [_song]);
      expect(songs.setLikedCalls, [(songId: 's1', liked: true)]);
      final liked = result.valueOrNull!;
      expect(liked.id, 's1');
      expect(liked.likedAt, clock);
      expect(sync.synced, [liked]);
    });

    test('decides with the saved state, not the stale argument', () async {
      songs.saveResult = Ok(_saved.copyWith(likedAt: DateTime(2020)));

      final result = await toggle(_song);

      expect(songs.setLikedCalls, [(songId: 's1', liked: false)]);
      expect(result.valueOrNull!.isLiked, isFalse);
      expect(sync.synced.single.isLiked, isFalse);
    });

    test('a save failure is returned without touching the like', () async {
      const failure = DatabaseFailure('disk full');
      songs.saveResult = const Err(failure);

      final result = await toggle(_song);

      expect(result.failureOrNull, same(failure));
      expect(songs.setLikedCalls, isEmpty);
      expect(sync.synced, isEmpty);
    });

    test('a like failure is returned without syncing', () async {
      const failure = DatabaseFailure('locked');
      songs.setLikedResult = const Err(failure);

      final result = await toggle(_song);

      expect(result.failureOrNull, same(failure));
      expect(sync.synced, isEmpty);
    });

    test(
      'F5: a sync failure is a LikedPlaylistSyncFailure with the new song',
      () async {
        sync.result = const Err(FakeLikedPlaylistSync.failure);

        final result = await toggle(_song);

        final failure = result.failureOrNull;
        expect(failure, isA<LikedPlaylistSyncFailure>());
        failure as LikedPlaylistSyncFailure;
        expect(failure.song.isLiked, isTrue);
        expect(failure.song.likedAt, clock);
        expect(failure.cause, same(FakeLikedPlaylistSync.failure));
        expect(failure, isA<SyncFailure>());
      },
    );

    test('defaults to the system clock when none is injected', () async {
      final before = DateTime.now();

      final result = await ToggleLikeUseCase(songs, sync)(_song);

      expect(result.valueOrNull!.likedAt!.isBefore(before), isFalse);
    });
  });
}
