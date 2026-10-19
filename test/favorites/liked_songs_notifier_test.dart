import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/playback_source.dart';
import 'package:koda/core/data/repositories/playlist_repository_impl.dart';
import 'package:koda/core/data/repositories/song_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/settings/settings_dao.dart';
import 'package:koda/core/storage/file_paths.dart';
import 'package:koda/features/downloads/data/download_manager.dart';
import 'package:koda/features/downloads/presentation/downloads_providers.dart';
import 'package:koda/features/favorites/domain/i_liked_playlist_sync.dart';
import 'package:koda/features/favorites/presentation/favorites_providers.dart';
import 'package:koda/core/database/playlist_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_services.dart';
import '../domain/fakes/fake_song_repository.dart';
import '../helpers/liked_playlist_override.dart';

class _FakeResolver implements PlaybackSourceResolver {
  @override
  Future<PlaybackSource> resolve(
    Song song, {
    bool forceRefresh = false,
  }) async =>
      RemoteStreamSource(Uri.parse('https://cdn.example/${song.sourceId}'));
}

Song _song(String sourceId) => Song(
  id: '',
  title: 'Canción $sourceId',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: sourceId,
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

List<String> _titles(List<Song> songs) => [for (final s in songs) s.title];

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase db;
  late SongRepositoryImpl repo;
  late FlakySongRepository flaky;
  late DownloadManager manager;
  late ProviderContainer container;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koda_liked');
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final songDao = SongDao(db);
    repo = SongRepositoryImpl(songDao);
    flaky = FlakySongRepository(repo);
    manager = DownloadManager(
      dio: Dio(),
      songRepository: flaky,
      paths: FilePaths(tmp),
      resolver: _FakeResolver(),
    );
    container = ProviderContainer.test(
      overrides: [
        songRepositoryProvider.overrideWithValue(flaky),
        downloadServiceProvider.overrideWithValue(manager),
        playlistRepositoryProvider.overrideWithValue(
          PlaylistRepositoryImpl(PlaylistDao(db, songDao)),
        ),
        settingsDaoProvider.overrideWithValue(SettingsDao(db)),
        likedPlaylistFromRepositories,
        downloadedKeysProvider.overrideWithValue(const {}),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await manager.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<Song> addLiked(String sourceId) async {
    final saved = _ok(await repo.save(_song(sourceId)));
    _ok(await repo.setLiked(saved.id, liked: true));
    return _ok(await repo.findById(saved.id));
  }

  /// Escucha las favoritas y espera su primera carga.
  Future<List<Song>> load() {
    container.listen(likedSongsProvider, (_, _) {});
    return container.read(likedSongsProvider.future);
  }

  Future<List<Song>> reloaded() => container.read(likedSongsProvider.future);

  LikedSongsNotifier notifier() => container.read(likedSongsProvider.notifier);

  /// Espera a que las favoritas cumplan [test] (p. ej. tras un aviso del
  /// [DownloadManager], que llega en segundo plano).
  Future<List<Song>> until(bool Function(List<Song> songs) test) {
    final done = Completer<List<Song>>();
    final sub = container.listen(likedSongsProvider, (_, next) {
      final songs = next.value;
      if (!next.isLoading &&
          songs != null &&
          test(songs) &&
          !done.isCompleted) {
        done.complete(songs);
      }
    }, fireImmediately: true);
    return done.future
        .timeout(const Duration(seconds: 5))
        .whenComplete(sub.close);
  }

  group('carga', () {
    test('Ok expone las favoritas y sus claves', () async {
      await addLiked('a');
      final b = await addLiked('b');

      expect(_titles(await load()), hasLength(2));
      expect(container.read(likedKeysProvider), {'youtube:a', 'youtube:b'});
      expect(container.read(isLikedProvider(b)), isTrue);
      expect(container.read(isLikedProvider(_song('c'))), isFalse);
    });

    test('un Err es un AsyncError con su Failure y sin reintentos', () async {
      flaky.getLikedFailures = 1;
      await expectLater(load(), throwsA(same(FlakySongRepository.failure)));
      final state = container.read(likedSongsProvider);
      expect(state.error, same(FlakySongRepository.failure));
      expect(state.isLoading, isFalse);
      expect(container.read(likedKeysProvider), isEmpty);

      await addLiked('a');
      container.invalidate(likedSongsProvider);
      expect(_titles(await reloaded()), ['Canción a']);
    });
  });

  group('toggle', () {
    test('marcar y desmarcar refresca las favoritas', () async {
      expect(await load(), isEmpty);

      final liked = _ok(await notifier().toggle(_song('x')));
      expect(_titles(await reloaded()), ['Canción x']);
      expect(container.read(isLikedProvider(_song('x'))), isTrue);

      _ok(await notifier().toggle(liked));
      expect(await reloaded(), isEmpty);
      expect(container.read(isLikedProvider(_song('x'))), isFalse);
    });

    test('un Err al marcar se devuelve y no cambia nada', () async {
      expect(await load(), isEmpty);
      final callsAfterLoad = flaky.getLikedCalls;
      flaky.setLikedFailures = 1;

      final result = await notifier().toggle(_song('x'));

      expect(result.failureOrNull, same(FlakySongRepository.failure));
      expect(await reloaded(), isEmpty);
      expect(flaky.getLikedCalls, callsAfterLoad, reason: 'nada que recargar');
    });

    test('F5: si falla "Me encanta" se devuelve el Err pero las favoritas '
        'se recargan (el "me gusta" sí cambió)', () async {
      final sync = FakeLikedPlaylistSync()
        ..result = const Err(FakeLikedPlaylistSync.failure);
      final failingSync = ProviderContainer.test(
        overrides: [
          songRepositoryProvider.overrideWithValue(flaky),
          downloadServiceProvider.overrideWithValue(manager),
          likedPlaylistProvider.overrideWithValue(sync),
          downloadedKeysProvider.overrideWithValue(const {}),
        ],
      );
      failingSync.listen(likedSongsProvider, (_, _) {});
      expect(await failingSync.read(likedSongsProvider.future), isEmpty);

      final result = await failingSync
          .read(likedSongsProvider.notifier)
          .toggle(_song('x'));

      final failure = result.failureOrNull;
      expect(failure, isA<LikedPlaylistSyncFailure>());
      expect((failure as LikedPlaylistSyncFailure).song.isLiked, isTrue);
      expect(sync.synced.single.title, 'Canción x');
      expect(_titles(await failingSync.read(likedSongsProvider.future)), [
        'Canción x',
      ]);
    });
  });

  group('puente con el DownloadManager', () {
    test('un aviso de downloadsChanged recarga las favoritas con su '
        'localPath actual', () async {
      final liked = await addLiked('a');
      final path = '${tmp.path}/${liked.id}.m4a';
      _ok(await repo.markDownloaded(liked.id, localPath: path, sizeBytes: 1));
      expect((await load()).single.localPath, path);

      _ok(await manager.forgetMissingFile(liked));

      final songs = await until((s) => s.single.localPath == null);
      expect(songs.single.isDownloaded, isFalse);
    });
  });
}
