import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/domain/i_playlist_importer.dart';
import 'package:sponify/features/playlists/domain/usecases/add_song_to_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/clear_playlist_cover_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/create_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/delete_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/get_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/get_playlists_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/import_youtube_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/move_song_in_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/remove_song_at_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/rename_playlist_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/restore_song_at_use_case.dart';
import 'package:sponify/features/playlists/domain/usecases/set_playlist_cover_from_file_use_case.dart';

import 'fakes/fake_playlist_repository.dart';
import 'fakes/fake_services.dart';

const _song = Song(
  id: 's1',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt1',
);

final _playlist = Playlist(
  id: 'p1',
  name: 'Mix',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _failure = DatabaseFailure('disk full');

void main() {
  late FakePlaylistRepository repo;

  setUp(() => repo = FakePlaylistRepository());

  group('AddSongToPlaylistUseCase', () {
    late AddSongToPlaylistUseCase addSong;

    setUp(() => addSong = AddSongToPlaylistUseCase(repo));

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
      repo.addSongResult = const Err(_failure);

      final result = await addSong('p1', _song);

      expect(result.failureOrNull, same(_failure));
    });
  });

  group('GetPlaylistsUseCase', () {
    test('returns the playlists', () async {
      repo.getAllResult = Ok([_playlist]);
      expect((await GetPlaylistsUseCase(repo)()).valueOrNull, [_playlist]);
    });

    test('propagates the failure unchanged', () async {
      repo.getAllResult = const Err(_failure);
      expect((await GetPlaylistsUseCase(repo)()).failureOrNull, _failure);
    });
  });

  group('GetPlaylistUseCase', () {
    test('returns the playlist by id', () async {
      repo.findByIdResult = Ok(_playlist);
      expect((await GetPlaylistUseCase(repo)('p1')).valueOrNull, _playlist);
      expect(repo.findByIdCalls, ['p1']);
    });

    test('propagates NotFoundFailure', () async {
      const notFound = NotFoundFailure('p1');
      repo.findByIdResult = const Err(notFound);
      expect((await GetPlaylistUseCase(repo)('p1')).failureOrNull, notFound);
    });
  });

  group('CreatePlaylistUseCase', () {
    test('creates the playlist with the name', () async {
      repo.createResult = Ok(_playlist);
      expect((await CreatePlaylistUseCase(repo)('Mix')).valueOrNull, _playlist);
      expect(repo.createCalls, ['Mix']);
    });

    test('propagates the failure unchanged', () async {
      repo.createResult = const Err(_failure);
      expect(
        (await CreatePlaylistUseCase(repo)('Mix')).failureOrNull,
        _failure,
      );
    });
  });

  group('RenamePlaylistUseCase', () {
    test('renames the playlist', () async {
      repo.renameResult = const Ok(unit);
      expect(await RenamePlaylistUseCase(repo)('p1', 'New'), const Ok(unit));
      expect(repo.renameCalls, [(id: 'p1', name: 'New')]);
    });

    test('propagates the failure unchanged', () async {
      repo.renameResult = const Err(_failure);
      expect(
        (await RenamePlaylistUseCase(repo)('p1', 'New')).failureOrNull,
        _failure,
      );
    });
  });

  group('RemoveSongAtUseCase', () {
    test('removes the song at the index', () async {
      repo.removeSongAtResult = const Ok(unit);
      expect(await RemoveSongAtUseCase(repo)('p1', 2), const Ok(unit));
      expect(repo.removeSongAtCalls, [(playlistId: 'p1', index: 2)]);
    });

    test('propagates the failure unchanged', () async {
      repo.removeSongAtResult = const Err(_failure);
      expect(
        (await RemoveSongAtUseCase(repo)('p1', 2)).failureOrNull,
        _failure,
      );
    });
  });

  group('MoveSongInPlaylistUseCase', () {
    test('moves the song', () async {
      repo.moveSongResult = const Ok(unit);
      expect(await MoveSongInPlaylistUseCase(repo)('p1', 0, 3), const Ok(unit));
      expect(repo.moveSongCalls, [
        (playlistId: 'p1', oldIndex: 0, newIndex: 3),
      ]);
    });

    test('propagates the failure unchanged', () async {
      repo.moveSongResult = const Err(_failure);
      expect(
        (await MoveSongInPlaylistUseCase(repo)('p1', 0, 3)).failureOrNull,
        _failure,
      );
    });
  });

  group('RestoreSongAtUseCase', () {
    late RestoreSongAtUseCase restore;

    setUp(() {
      restore = RestoreSongAtUseCase(repo);
      repo.moveSongResult = const Ok(unit);
    });

    test('appends and moves the song back to its position', () async {
      expect(
        await restore('p1', _song, position: 1, appendedAt: 4),
        const Ok(true),
      );
      expect(repo.addSongCalls, [(playlistId: 'p1', song: _song)]);
      expect(repo.moveSongCalls, [
        (playlistId: 'p1', oldIndex: 4, newIndex: 1),
      ]);
    });

    test('does not move when the position is the end', () async {
      expect(
        await restore('p1', _song, position: 4, appendedAt: 4),
        const Ok(true),
      );
      expect(repo.moveSongCalls, isEmpty);
    });

    test('returns Ok(false) without moving when already present', () async {
      repo.addSongResult = const Ok(false);
      expect(
        await restore('p1', _song, position: 0, appendedAt: 4),
        const Ok(false),
      );
      expect(repo.moveSongCalls, isEmpty);
    });

    test('propagates an add failure without moving', () async {
      repo.addSongResult = const Err(_failure);
      final result = await restore('p1', _song, position: 0, appendedAt: 4);
      expect(result.failureOrNull, _failure);
      expect(repo.moveSongCalls, isEmpty);
    });

    test('propagates a move failure', () async {
      repo.moveSongResult = const Err(_failure);
      final result = await restore('p1', _song, position: 0, appendedAt: 4);
      expect(result.failureOrNull, _failure);
    });
  });

  group('cover use cases', () {
    late FakePlaylistCoverService covers;

    setUp(() => covers = FakePlaylistCoverService());

    test('DeletePlaylistUseCase deletes through the cover service', () async {
      expect(await DeletePlaylistUseCase(covers)('p1'), const Ok(unit));
      expect(covers.calls, ['deletePlaylist(p1)']);
    });

    test('SetPlaylistCoverFromFileUseCase copies the image', () async {
      expect(
        await SetPlaylistCoverFromFileUseCase(covers)('p1', '/img.png'),
        const Ok(unit),
      );
      expect(covers.calls, ['setFromFile(p1, /img.png)']);
    });

    test('ClearPlaylistCoverUseCase clears the cover', () async {
      expect(await ClearPlaylistCoverUseCase(covers)('p1'), const Ok(unit));
      expect(covers.calls, ['clear(p1)']);
    });

    test('a service Err is propagated unchanged', () async {
      covers.result = const Err(_failure);
      expect(
        (await DeletePlaylistUseCase(covers)('p1')).failureOrNull,
        _failure,
      );
      expect(
        (await SetPlaylistCoverFromFileUseCase(covers)(
          'p1',
          'x',
        )).failureOrNull,
        _failure,
      );
      expect(
        (await ClearPlaylistCoverUseCase(covers)('p1')).failureOrNull,
        _failure,
      );
    });

    test('an exception from the service becomes a StorageFailure', () async {
      covers.error = const FormatException('io');
      final result = await SetPlaylistCoverFromFileUseCase(covers)('p1', 'x');
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(result.failureOrNull!.cause, isA<FormatException>());
    });
  });

  group('ImportYoutubePlaylistUseCase', () {
    late FakePlaylistImporter importer;
    late ImportYoutubePlaylistUseCase import;

    setUp(() {
      importer = FakePlaylistImporter();
      import = ImportYoutubePlaylistUseCase(importer);
    });

    test('returns the import result and reports progress', () async {
      importer.progress = const [(0, 1), (1, 1)];
      final calls = <(int, int)>[];

      final result = await import(
        'link',
        onProgress: (done, total) => calls.add((done, total)),
      );

      expect(result.valueOrNull?.playlistId, 'p1');
      expect(importer.calls, ['link']);
      expect(calls, [(0, 1), (1, 1)]);
    });

    test('propagates a typed import failure', () async {
      importer.result = const Err(InvalidPlaylistLinkFailure());
      expect(
        (await import('x')).failureOrNull,
        isA<InvalidPlaylistLinkFailure>(),
      );
    });

    test('an exception from the importer becomes a NetworkFailure', () async {
      importer.error = Exception('offline');
      expect((await import('x')).failureOrNull, isA<NetworkFailure>());
    });
  });
}
