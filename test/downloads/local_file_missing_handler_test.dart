import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/playback_source.dart';
import 'package:koda/core/data/repositories/song_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/storage/file_paths.dart';
import 'package:koda/features/downloads/data/download_manager.dart';
import 'package:koda/features/downloads/data/local_file_missing_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_song_repository.dart';

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

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase db;
  late SongRepositoryImpl repo;
  late FlakySongRepository flaky;
  late List<String> logs;
  late LocalFileMissingHandler handler;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koda_missing');
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SongRepositoryImpl(SongDao(db));
    flaky = FlakySongRepository(repo);
    logs = [];
    handler = LocalFileMissingHandler(flaky, log: logs.add);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// Canción marcada como descargada cuyo archivo ya no existe.
  Future<Song> addMissing(String sourceId) async {
    final saved = _ok(await repo.save(_song(sourceId)));
    return _ok(
      await repo.markDownloaded(
        saved.id,
        localPath: '${tmp.path}/${saved.id}.m4a',
        sizeBytes: 100,
      ),
    );
  }

  test('sin DownloadManager todavía (arranque del audio) limpia la '
      'descarga en la BD sin lanzar', () async {
    final song = await addMissing('a');

    await handler(song);

    expect(_ok(await repo.findById(song.id)).isDownloaded, isFalse);
    expect(logs, isEmpty);
  });

  test('sin DownloadManager, un Err se registra y no lanza', () async {
    final song = await addMissing('a');
    flaky.clearDownloadFailures = 1;

    await handler(song);

    expect(logs, hasLength(1));
    expect(_ok(await repo.findById(song.id)).isDownloaded, isTrue);
  });

  test(
    'con DownloadManager delega en él y avisa de downloadsChanged',
    () async {
      final manager = DownloadManager(
        dio: Dio(),
        songRepository: flaky,
        paths: FilePaths(tmp),
        resolver: _FakeResolver(),
      );
      addTearDown(manager.dispose);
      handler.manager = manager;
      final song = await addMissing('a');
      final changed = manager.downloadsChanged.first;

      await handler(song);

      expect((await changed).isDownloaded, isFalse);
      expect(_ok(await repo.findById(song.id)).isDownloaded, isFalse);
      expect(logs, isEmpty);
    },
  );

  test('con DownloadManager, un Err se registra y no lanza', () async {
    final manager = DownloadManager(
      dio: Dio(),
      songRepository: flaky,
      paths: FilePaths(tmp),
      resolver: _FakeResolver(),
    );
    addTearDown(manager.dispose);
    handler.manager = manager;
    final song = await addMissing('a');
    flaky.clearDownloadFailures = 1;

    await handler(song);

    expect(logs, hasLength(1));
  });
}
