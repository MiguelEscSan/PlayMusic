import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/downloads/domain/download_task.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

Song _song(String sourceId) => Song(
  id: '',
  title: 'Canción $sourceId',
  artist: 'Artista',
  durationMs: 180000,
  source: SongSource.youtube,
  sourceId: sourceId,
);

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
    tmp = await Directory.systemTemp.createTemp('sponify_test');
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
      songDao: dao,
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
    final saved = await dao.upsert(song);
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
  });

  test('borrar elimina el archivo y vuelve a streaming', () async {
    final song = _song('del');
    final done = waitFor(song, DownloadStatus.completed);
    await manager.download(song);
    final path = (await done).song.localPath!;

    final updated = await manager.delete(song);
    expect(updated.isDownloaded, isFalse);
    expect(File(path).existsSync(), isFalse);
    expect(await dao.downloaded(), isEmpty);
    expect(storageChanges.last.isDownloaded, isFalse);
  });
}
