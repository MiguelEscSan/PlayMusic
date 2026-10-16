import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/di/repository_providers.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/downloads/domain/download_task.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_song_repository.dart';

/// Servidor que devuelve el archivo entero de una vez.
class _WholeFileServer implements HttpClientAdapter {
  final body = Uint8List.fromList(List.generate(3000, (i) => i % 251));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    Stream.value(body),
    200,
    headers: {
      'content-length': ['${body.length}'],
    },
  );

  @override
  void close({bool force = false}) {}
}

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
    tmp = await Directory.systemTemp.createTemp('sponify_downloads');
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SongRepositoryImpl(SongDao(db));
    flaky = FlakySongRepository(repo);
    manager = DownloadManager(
      dio: Dio()..httpClientAdapter = _WholeFileServer(),
      songRepository: flaky,
      paths: FilePaths(tmp),
      resolver: _FakeResolver(),
    );
    container = ProviderContainer.test(
      overrides: [
        songRepositoryProvider.overrideWithValue(flaky),
        downloadManagerProvider.overrideWithValue(manager),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await manager.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// Guarda una canción como descargada, con su archivo en disco.
  Future<Song> addDownloaded(String sourceId, {int sizeBytes = 100}) async {
    final saved = _ok(await repo.save(_song(sourceId)));
    final file = File('${tmp.path}/${saved.id}.m4a')..writeAsBytesSync([1]);
    return _ok(
      await repo.markDownloaded(
        saved.id,
        localPath: file.path,
        sizeBytes: sizeBytes,
      ),
    );
  }

  /// Escucha las descargas y espera su primera carga.
  Future<List<Song>> load() {
    container.listen(downloadedSongsProvider, (_, _) {});
    return container.read(downloadedSongsProvider.future);
  }

  DownloadsNotifier notifier() =>
      container.read(downloadedSongsProvider.notifier);

  /// Espera a que las descargas cumplan [test] (p. ej. tras un aviso del
  /// [DownloadManager], que llega en segundo plano).
  Future<List<Song>> until(bool Function(List<Song> songs) test) {
    final done = Completer<List<Song>>();
    final sub = container.listen(downloadedSongsProvider, (_, next) {
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
    test('Ok expone las descargas, el espacio y sus claves', () async {
      await addDownloaded('a', sizeBytes: 100);
      await addDownloaded('b', sizeBytes: 50);

      expect(_titles(await load()), ['Canción b', 'Canción a']);
      expect(container.read(downloadsSizeProvider), 150);
      expect(container.read(downloadedKeysProvider), {
        'youtube:a',
        'youtube:b',
      });
    });

    test('un Err es un AsyncError con su Failure y sin reintentos', () async {
      flaky.getDownloadedFailures = 1;
      await expectLater(load(), throwsA(same(FlakySongRepository.failure)));
      final state = container.read(downloadedSongsProvider);
      expect(state.error, same(FlakySongRepository.failure));
      expect(state.isLoading, isFalse);
      expect(container.read(downloadedKeysProvider), isEmpty);
      expect(container.read(downloadsSizeProvider), 0);

      await addDownloaded('a');
      container.invalidate(downloadedSongsProvider);
      expect(_titles(await container.read(downloadedSongsProvider.future)), [
        'Canción a',
      ]);
    });
  });

  group('delete', () {
    test('Ok borra el archivo y la quita del estado y de la BD', () async {
      final song = await addDownloaded('a');
      await load();

      final deleted = _ok(await notifier().delete(song));

      expect(deleted.isDownloaded, isFalse);
      expect(File(song.localPath!).existsSync(), isFalse);
      expect(_titles(await container.read(downloadedSongsProvider.future)), []);
      expect(_ok(await repo.getDownloaded()), isEmpty);
    });

    test('Err se devuelve y el estado sigue siendo el de la BD', () async {
      final song = await addDownloaded('a');
      await load();
      flaky.clearDownloadFailures = 1;

      final result = await notifier().delete(song);

      expect(result.failureOrNull, same(FlakySongRepository.failure));
      expect(_titles(await container.read(downloadedSongsProvider.future)), [
        'Canción a',
      ]);
    });
  });

  group('deleteAll', () {
    test('Ok vacía las descargas', () async {
      await addDownloaded('a');
      await addDownloaded('b');
      await load();

      _ok(await notifier().deleteAll());

      expect(await container.read(downloadedSongsProvider.future), isEmpty);
      expect(container.read(downloadsSizeProvider), 0);
    });

    test('Err se devuelve y se recarga lo que quedó', () async {
      await addDownloaded('a');
      await addDownloaded('b');
      await load();
      flaky.getDownloadedFailures = 1;

      final result = await notifier().deleteAll();

      expect(result.failureOrNull, same(FlakySongRepository.failure));
      expect(
        _titles(await container.read(downloadedSongsProvider.future)),
        unorderedEquals(['Canción a', 'Canción b']),
      );
    });
  });

  group('puente con el DownloadManager', () {
    test('una descarga terminada en segundo plano aparece sin recargar a '
        'mano, y el progreso no recarga', () async {
      expect(await load(), isEmpty);
      final callsAfterLoad = flaky.getDownloadedCalls;
      final song = _song('bg');
      final completed = manager
          .watch(song)
          .firstWhere((t) => t?.status == DownloadStatus.completed);

      await manager.download(song);
      await completed;
      final songs = await until((s) => s.isNotEmpty);

      expect(_titles(songs), ['Canción bg']);
      expect(container.read(downloadedKeysProvider), {'youtube:bg'});
      expect(container.read(downloadsSizeProvider), 3000);
      expect(
        flaky.getDownloadedCalls,
        callsAfterLoad + 1,
        reason: 'solo recarga al terminar, no con cada aviso de progreso',
      );
    });

    test('borrar desde el DownloadManager (sin tarea en esta sesión) '
        'la quita', () async {
      final song = await addDownloaded('a');
      expect(await load(), hasLength(1));

      _ok(await manager.delete(song));

      expect(await until((s) => s.isEmpty), isEmpty);
    });

    test('un archivo perdido que el DownloadManager olvida desaparece de '
        'Descargas', () async {
      final song = await addDownloaded('a');
      expect(await load(), hasLength(1));

      _ok(await manager.forgetMissingFile(song));

      expect(await until((s) => s.isEmpty), isEmpty);
      expect(_ok(await repo.findById(song.id)).isDownloaded, isFalse);
    });
  });
}
