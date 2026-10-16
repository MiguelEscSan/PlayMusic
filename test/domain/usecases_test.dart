import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/favorites/domain/usecases/toggle_favorite_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/add_song_to_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/remove_song_from_playlist_use_case.dart';

import 'fakes/fake_playlist_repository.dart';
import 'fakes/fake_song_repository.dart';

const _song = Song(
  id: 's1',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt1',
);

void main() {
  group('AddSongToPlaylistUseCase', () {
    late FakePlaylistRepository repo;
    late AddSongToPlaylistUseCase addSong;

    setUp(() {
      repo = FakePlaylistRepository();
      addSong = AddSongToPlaylistUseCase(repo);
    });

    test(
      'delegates to the repository and returns Ok(true) when added',
      () async {
        final result = await addSong('p1', _song);

        expect(result, const Ok(true));
        expect(repo.addSongCalls, [(playlistId: 'p1', song: _song)]);
      },
    );

    test('returns Ok(false) when the song was already present', () async {
      repo.addSongResult = const Ok(false);

      expect(await addSong('p1', _song), const Ok(false));
    });

    test('propagates the failure unchanged', () async {
      const failure = DatabaseFailure('disk full');
      repo.addSongResult = const Err(failure);

      final result = await addSong('p1', _song);

      expect(result.failureOrNull, same(failure));
    });
  });

  group('RemoveSongFromPlaylistUseCase', () {
    late FakePlaylistRepository repo;
    late RemoveSongFromPlaylistUseCase removeSong;

    setUp(() {
      repo = FakePlaylistRepository();
      removeSong = RemoveSongFromPlaylistUseCase(repo);
    });

    test(
      'delegates to the repository and returns Ok(true) when removed',
      () async {
        final result = await removeSong('p1', 's1');

        expect(result, const Ok(true));
        expect(repo.removeSongCalls, [(playlistId: 'p1', songId: 's1')]);
      },
    );

    test('returns Ok(false) when the song was not present', () async {
      repo.removeSongResult = const Ok(false);

      expect(await removeSong('p1', 's1'), const Ok(false));
    });

    test('propagates the failure unchanged', () async {
      const failure = NotFoundFailure('playlist p1');
      repo.removeSongResult = const Err(failure);

      final result = await removeSong('p1', 's1');

      expect(result.failureOrNull, same(failure));
    });
  });

  group('ToggleFavoriteUseCase', () {
    final clock = DateTime(2026, 10, 16, 12);
    late FakeSongRepository repo;
    late ToggleFavoriteUseCase toggle;

    setUp(() {
      repo = FakeSongRepository();
      toggle = ToggleFavoriteUseCase(repo, now: () => clock);
    });

    test('likes an unliked song and stamps likedAt with the clock', () async {
      final result = await toggle(_song);

      expect(repo.setLikedCalls, [(songId: 's1', liked: true)]);
      final liked = result.valueOrNull!;
      expect(liked.isLiked, isTrue);
      expect(liked.likedAt, clock);
    });

    test('unlikes a liked song and clears likedAt', () async {
      final likedSong = _song.copyWith(likedAt: DateTime(2020));

      final result = await toggle(likedSong);

      expect(repo.setLikedCalls, [(songId: 's1', liked: false)]);
      final unliked = result.valueOrNull!;
      expect(unliked.isLiked, isFalse);
      expect(unliked.likedAt, isNull);
    });

    test('propagates the failure unchanged', () async {
      const failure = DatabaseFailure('locked');
      repo.setLikedResult = const Err(failure);

      final result = await toggle(_song);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, same(failure));
    });

    test('defaults to the system clock when none is injected', () async {
      final before = DateTime.now();

      final result = await ToggleFavoriteUseCase(repo)(_song);

      final likedAt = result.valueOrNull!.likedAt!;
      expect(likedAt.isBefore(before), isFalse);
    });
  });
}
