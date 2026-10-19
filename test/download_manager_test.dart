import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/playback_source.dart';
import 'package:koda/core/data/models/song_model.dart';
import 'package:koda/core/data/repositories/song_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_song_repository.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/storage/file_paths.dart';
import 'package:koda/features/downloads/data/download_manager.dart';
import 'package:koda/features/downloads/domain/download_task.dart';
import 'package:koda/features/downloads/presentation/download_task_progress.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_song_repository.dart';

/// Servidor falso que respeta la cabecera Range, como un CDN real.
class _RangeServer implements HttpClientAdapter {
  _RangeServer(this.body);

  final Uint8List body;
  final List<String?> ranges = [];
  int failNextWith = 0;
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gate != null) await gate!.future;
    if (failNextWith != 0) {
      final code = failNextWith;
      failNextWith = 0;
      return ResponseBody.fromString('', code);
    }
    final range = options.headers['Range'] as String?;
    ranges.add(range);
    final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range ?? '');
    final start = int.parse(m!.group(1)!);
    if (start >= body.length) return ResponseBody.fromString('', 416);
    final end = (int.parse(m.group(2)!) + 1).clamp(0, body.length);
    return ResponseBody(
      Stream.value(body.sublist(start, end)),
      206,
      headers: {
        'content-range': ['bytes $start-${end - 1}/${body.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeResolver implements PlaybackSourceResolver {
  int calls = 0;
  final List<bool> forced = [];

  @override
  Future<PlaybackSource> resolve(Song song, {bool forceRefresh = false}) async {
    calls++;
    forced.add(forceRefresh);
    return RemoteStreamSource(
      Uri.parse('https://cdn.example/${song.sourceId}?mime=audio%2Fmp4'),
    );
  }
}

/// Repositorio real salvo [markDownloaded], que siempre falla.
class _MarkDownloadedFails implements ISongRepository {
  _MarkDownloadedFails(this._inner);

  final ISongRepository _inner;

  @override
  Future<Result<Song>> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
  }) async => const Err(UnexpectedFailure('disco lleno'));

  @override
  Future<Result<Song>> save(Song song) => _inner.save(song);

  @override
  Future<Result<Song>> findById(String id) => _inner.findById(id);

  @override
  Future<Result<Song>> findBySource(SongSource source, String sourceId) =>
      _inner.findBySource(source, sourceId);

  @override
  Future<Result<List<Song>>> getDownloaded() => _inner.getDownloaded();

  @override
  Future<Result<int>> getDownloadedBytes() => _inner.getDownloadedBytes();

  @override
  Future<Result<List<Song>>> getLiked() => _inner.getLiked();

  @override
  Future<Result<Unit>> setLiked(String songId, {required bool liked}) =>
      _inner.setLiked(songId, liked: liked);

  @override
  Future<Result<Unit>> clearDownload(String songId) =>
      _inner.clearDownload(songId);
}

Song _song(String sourceId) => Song(
  id: '',
  title: 'Canción $sourceId',
  artist: 'Artista',
  durationMs: 180000,
  source: SongSource.youtube,
  sourceId: sourceId,
);

void _expectOk(Result<Object?> result) =>
    expect(result.isOk, isTrue, reason: '$result');

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late AppDatabase db;
  late SongDao dao;
  late _RangeServer server;
  late _FakeResolver resolver;
  late List<Song> storageChanges;
  late DownloadManager manager;
  final body = Uint8List.fromList(List.generate(25000, (i) => i % 251));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koda_test');
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = SongDao(db);
    server = _RangeServer(body);
    resolver = _FakeResolver();
    storageChanges = [];
    manager = DownloadManager(
      dio: Dio()..httpClientAdapter = server,
      songRepository: SongRepositoryImpl(dao),
      paths: FilePaths(tmp),
      resolver: resolver,
      onStorageChanged: (s) async => storageChanges.add(s),
      chunkSize: 10000,
    );
  });

  tearDown(() async {
    await manager.dispose();
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<DownloadTask> waitFor(Song song, DownloadStatus status) => manager
      .watch(song)
      .firstWhere((t) => t?.status == status)
      .then((t) => t!);

  test('descarga por trozos, guarda en BD y avisa al reproductor', () async {
    final song = _song('abc');
    final done = waitFor(song, DownloadStatus.completed);
    final saved = await manager.download(song);
    final task = await done;

    expect(saved.id, isNotEmpty);
    expect(task.progress, 1.0);
    expect(server.ranges, [
      'bytes=0-9999',
      'bytes=10000-19999',
      'bytes=20000-29999',
    ]);

    final file = File(task.song.localPath!);
    expect(file.path, endsWith('${saved.id}.m4a'));
    expect(await file.readAsBytes(), body);
    expect(File('${tmp.path}/${saved.id}.part').existsSync(), isFalse);

    final fromDb = await dao.findById(saved.id);
    expect(fromDb!.isDownloaded, isTrue);
    expect(fromDb.fileSizeBytes, body.length);
    expect(await dao.downloadedBytes(), body.length);
    expect(storageChanges.single.isDownloaded, isTrue);
  });

  test('una canción ya descargada no se vuelve a bajar', () async {
    final song = _song('abc');
    final first = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    await first;
    final requests = server.ranges.length;

    await manager.download(song);
    expect(server.ranges.length, requests);
  });

  test('URL caducada (403) -> pide una nueva y continúa', () async {
    server.failNextWith = 403;
    final song = _song('exp');
    final done = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    await done;
    expect(resolver.forced, [false, true]);
  });

  test('reanuda desde el .part tras un fallo', () async {
    final song = _song('res');
    final saved = await dao.upsert(SongModel.fromEntity(song));
    await File('${tmp.path}/${saved.id}.part')
        .writeAsBytes(body.sublist(0, 10000));

    final done = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    final task = await done;
    expect(server.ranges.first, 'bytes=10000-19999');
    expect(await File(task.song.localPath!).readAsBytes(), body);
  });

  test('cancelar en cola borra el estado activo', () async {
    server.gate = Completer();
    final a = _song('a'), b = _song('b'), c = _song('c');
    // Esperamos a que a y b acaben: si el tearDown borra la carpeta mientras
    // siguen escribiendo, en Windows falla con "acceso denegado".
    final aDone = waitFor(a, DownloadStatus.completed);
    final bDone = waitFor(b, DownloadStatus.completed);
    await manager.download(a);
    await manager.download(b);
    await manager.download(c); // tercera: queda en cola (máx. 2)
    expect(
      manager.tasks[DownloadManager.keyOf(c)]!.status,
      DownloadStatus.queued,
    );

    await manager.cancel(c);
    expect(
      manager.tasks[DownloadManager.keyOf(c)]!.status,
      DownloadStatus.cancelled,
    );
    server.gate!.complete();
    await Future.wait([aDone, bDone]);
  });

  test('borrar elimina el archivo y vuelve a streaming', () async {
    final song = _song('del');
    final done = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    final path = (await done).song.localPath!;

    final result = await manager.delete(song);
    expect(result.isOk, isTrue, reason: '$result');
    final updated = result.valueOrNull!;
    expect(updated.isDownloaded, isFalse);
    expect(File(path).existsSync(), isFalse);
    expect(await dao.downloaded(), isEmpty);
    expect(storageChanges.last.isDownloaded, isFalse);
  });

  test('un fallo del repositorio no lanza: la tarea queda fallida', () async {
    final failing = DownloadManager(
      dio: Dio()..httpClientAdapter = server,
      songRepository: FakeSongRepository(),
      paths: FilePaths(tmp),
      resolver: resolver,
    );
    addTearDown(failing.dispose);
    final song = _song('err');

    expect(await failing.download(song), song);
    final task = failing.tasks[DownloadManager.keyOf(song)]!;
    expect(task.status, DownloadStatus.failed);
    expect(task.error, 'not configured in fake');
    expect(resolver.calls, 0);

    expect((await failing.delete(song)).isErr, isTrue);
    expect((await failing.deleteAll()).isErr, isTrue);
    expect(
      (await failing.forgetMissingFile(song.copyWith(id: 'x'))).isErr,
      isTrue,
    );
  });

  test('downloadsChanged avisa al terminar, al borrar y al olvidar un '
      'archivo perdido, no con el progreso', () async {
    final changes = <Song>[];
    final sub = manager.downloadsChanged.listen(changes.add);
    addTearDown(sub.cancel);
    final song = _song('notify');

    final done = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    final downloaded = (await done).song;
    await pumpEventQueue();
    expect(changes.map((s) => s.isDownloaded), [true]);

    _expectOk(await manager.delete(downloaded));
    await pumpEventQueue();
    expect(changes.map((s) => s.isDownloaded), [true, false]);

    final again = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    final redownloaded = (await again).song;
    await File(redownloaded.localPath!).delete();
    _expectOk(await manager.forgetMissingFile(redownloaded));
    await pumpEventQueue();

    expect(changes.map((s) => s.isDownloaded), [true, false, true, false]);
    expect((await dao.findById(redownloaded.id))!.isDownloaded, isFalse);
    expect(manager.tasks, isEmpty);
  });

  test('si la BD no registra el archivo, se borra del disco', () async {
    final failing = DownloadManager(
      dio: Dio()..httpClientAdapter = server,
      songRepository: _MarkDownloadedFails(SongRepositoryImpl(dao)),
      paths: FilePaths(tmp),
      resolver: resolver,
      chunkSize: 10000,
    );
    addTearDown(failing.dispose);
    final song = _song('untracked');

    final failed = failing
        .watch(song)
        .firstWhere((t) => t?.status == DownloadStatus.failed);
    await failing.download(song);
    final task = (await failed)!;

    expect(task.error, 'disco lleno');
    expect(
      tmp.listSync().map((e) => e.path),
      isEmpty,
      reason: 'ni el archivo final ni el .part quedan sin registrar',
    );
    expect(await dao.downloaded(), isEmpty);
  });

  group('solo con wifi (canDownload)', () {
    var allowed = false;

    setUp(() async {
      allowed = false;
      await manager.dispose();
      manager = DownloadManager(
        dio: Dio()..httpClientAdapter = server,
        songRepository: SongRepositoryImpl(dao),
        paths: FilePaths(tmp),
        resolver: resolver,
        chunkSize: 10000,
        canDownload: () async => allowed,
      );
    });

    test('sin permiso la descarga falla sin pedir nada', () async {
      final song = _song('wifi');
      final failed = waitFor(song, DownloadStatus.failed);
      await manager.download(song);
      final task = await failed;

      expect(
        task.error,
        'Esperando wifi: activa la descarga con datos en Ajustes',
      );
      expect(resolver.calls, 0);
      expect(server.ranges, isEmpty);
      expect(await dao.downloaded(), isEmpty);
    });

    test('al reintentar con permiso se descarga', () async {
      final song = _song('wifi');
      final failed = waitFor(song, DownloadStatus.failed);
      await manager.download(song);
      await failed;

      allowed = true;
      final done = waitFor(song, DownloadStatus.completed);
      await manager.download(song);
      expect((await done).progress, 1.0);
    });
  });
}
