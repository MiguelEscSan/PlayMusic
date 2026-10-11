import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/audio/playback_source.dart';
import '../../../core/database/song_dao.dart';
import '../../../core/models/song.dart';
import '../../../core/storage/file_paths.dart';
import '../domain/download_task.dart';

typedef StorageChangedCallback = Future<void> Function(Song song);

/// Descarga canciones al almacenamiento de la app con progreso en tiempo
/// real, una cola con límite de concurrencia, cancelación y reanudación.
///
/// Flujo de una descarga:
///   1. Se guarda la canción en la BD (upsert) para tener un id estable.
///   2. Se pide una URL fresca al resolver (la misma lógica que el reproductor).
///   3. Se descarga a `<id>.part` en trozos de ~9 MB (YouTube limita la
///      velocidad de las peticiones de archivo completo).
///   4. Al terminar se renombra a `<id>.m4a`, se actualiza la BD y se avisa
///      al reproductor para que la próxima vez use el archivo local.
///
/// Si una descarga falla, el `.part` se conserva y al reintentar continúa
/// donde se quedó.
class DownloadManager {
  DownloadManager({
    required this._dio,
    required this._songDao,
    required this._paths,
    required this._resolver,
    this.onStorageChanged,
    this.maxConcurrent = 2,
    this.chunkSize = 9 * 1024 * 1024,
  });

  final Dio _dio;
  final SongDao _songDao;
  final FilePaths _paths;
  final PlaybackSourceResolver _resolver;

  /// Normalmente `AudioPlayerService.onSongStorageChanged`.
  final StorageChangedCallback? onStorageChanged;

  final int maxConcurrent;
  final int chunkSize;

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressEmit = {};
  final Queue<String> _pending = Queue();
  final _controller = StreamController<Map<String, DownloadTask>>.broadcast();
  int _running = 0;

  /// Clave de una canción: no depende del id de BD, así la UI puede seguir
  /// el progreso de un resultado de búsqueda que aún no está guardado.
  static String keyOf(Song song) => '${song.source.name}:${song.sourceId}';

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------

  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  /// Todas las descargas en curso o recientes; emite en cada cambio.
  Stream<Map<String, DownloadTask>> get tasksStream async* {
    yield tasks;
    yield* _controller.stream;
  }

  /// Progreso de una canción concreta (para el botón de descarga).
  Stream<DownloadTask?> watch(Song song) {
    final key = keyOf(song);
    return tasksStream.map((all) => all[key]).distinct();
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  /// Encola la descarga. Devuelve la canción tal como quedó en la BD.
  Future<Song> download(Song song) async {
    final key = keyOf(song);
    final active = _tasks[key];
    if (active != null && active.isActive) return active.song;

    final saved = await _songDao.upsert(song);
    if (saved.isDownloaded && await File(saved.localPath!).exists()) {
      _set(key, DownloadTask(song: saved, status: DownloadStatus.completed));
      return saved;
    }

    _set(key, DownloadTask(song: saved, status: DownloadStatus.queued));
    _pending.add(key);
    _pump();
    return saved;
  }

  /// Cancela una descarga en cola o en curso y borra el archivo parcial.
  Future<void> cancel(Song song) async {
    final key = keyOf(song);
    final task = _tasks[key];
    if (task == null || !task.isActive) return;
    if (_pending.remove(key)) {
      await _deleteIfExists(File(_paths.partialFile(task.song.id)));
      _set(key, task.copyWith(status: DownloadStatus.cancelled));
    } else {
      _cancelTokens[key]?.cancel('cancelada por el usuario');
    }
  }

  /// Borra el archivo descargado; la canción vuelve a reproducirse en
  /// streaming y sigue en sus playlists.
  Future<Song> delete(Song song) async {
    await cancel(song);
    final saved = song.id.isEmpty
        ? await _songDao.findBySource(song.source, song.sourceId)
        : await _songDao.findById(song.id);
    if (saved == null) return song;

    if (saved.localPath case final path?) await _deleteIfExists(File(path));
    await _deleteIfExists(File(_paths.partialFile(saved.id)));
    await _songDao.clearDownload(saved.id);

    final updated = saved.copyWith(clearLocalFile: true);
    _tasks.remove(keyOf(song));
    _emit();
    await onStorageChanged?.call(updated);
    return updated;
  }

  /// Vacía todas las descargas (botón "Borrar todo" de la vista Descargas).
  Future<void> deleteAll() async {
    for (final song in await _songDao.downloaded()) {
      await delete(song);
    }
  }

  Future<void> dispose() async {
    for (final token in _cancelTokens.values) {
      token.cancel('dispose');
    }
    await _controller.close();
  }

  // ---------------------------------------------------------------------------
  // Cola
  // ---------------------------------------------------------------------------

  void _pump() {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final key = _pending.removeFirst();
      if (_tasks[key]?.status != DownloadStatus.queued) continue;
      _running++;
      unawaited(
        _run(key).whenComplete(() {
          _running--;
          _pump();
        }),
      );
    }
  }

  Future<void> _run(String key) async {
    final song = _tasks[key]!.song;
    final token = CancelToken();
    _cancelTokens[key] = token;
    _set(key, _tasks[key]!.copyWith(status: DownloadStatus.downloading));
    final part = File(_paths.partialFile(song.id));

    try {
      final url = await _downloadWithRetry(song, part, token, key);
      final finalPath = _paths.songFile(song.id, _extensionFor(url));
      await part.rename(finalPath);
      final size = await File(finalPath).length();
      final updated = await _songDao.markDownloaded(
        song.id,
        localPath: finalPath,
        sizeBytes: size,
      );
      _set(
        key,
        DownloadTask(
          song: updated,
          status: DownloadStatus.completed,
          receivedBytes: size,
          totalBytes: size,
        ),
      );
      await onStorageChanged?.call(updated);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        await _deleteIfExists(part);
        _set(key, _tasks[key]!.copyWith(status: DownloadStatus.cancelled));
      } else {
        // El .part se queda: reintentar continúa desde ahí.
        _set(key, _failed(key, _describe(e)));
      }
    } on SongUnavailableException catch (e) {
      _set(key, _failed(key, e.reason ?? 'Canción no disponible'));
    } catch (e) {
      _set(key, _failed(key, e.toString()));
    } finally {
      _cancelTokens.remove(key);
      _lastProgressEmit.remove(key);
    }
  }

  DownloadTask _failed(String key, String error) =>
      _tasks[key]!.copyWith(status: DownloadStatus.failed, error: error);

  // ---------------------------------------------------------------------------
  // Descarga por trozos
  // ---------------------------------------------------------------------------

  /// Si el servidor rechaza la URL (caducada), se pide una nueva y se
  /// reintenta una vez sin perder lo ya descargado.
  Future<Uri> _downloadWithRetry(
    Song song,
    File part,
    CancelToken token,
    String key,
  ) async {
    var forceRefresh = false;
    for (var attempt = 0; ; attempt++) {
      final source = await _resolver.resolve(
        song.copyWith(clearLocalFile: true),
        forceRefresh: forceRefresh,
      );
      if (source is! RemoteStreamSource) {
        throw StateError('El resolver no devolvió una URL remota');
      }
      try {
        await _downloadChunked(source, part, token, key);
        return source.uri;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final expired = status == 403 || status == 410;
        if (attempt == 0 && expired && !CancelToken.isCancel(e)) {
          forceRefresh = true;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _downloadChunked(
    RemoteStreamSource source,
    File part,
    CancelToken token,
    String key,
  ) async {
    final uri = source.uri;
    var received = await part.exists() ? await part.length() : 0;
    // googlevideo indica el tamaño total en `clen`; si no, lo sacamos de
    // Content-Range / Content-Length de la primera respuesta.
    int? total = int.tryParse(uri.queryParameters['clen'] ?? '');
    // YouTube acepta el rango por query (`&range=a-b`) salvo en URLs del
    // cliente ANDROID, que exigen la cabecera Range.
    final rangeInQuery =
        uri.host.endsWith('googlevideo.com') &&
        uri.queryParameters['c'] != 'ANDROID';

    final sink = part.openWrite(mode: FileMode.append);
    try {
      while (total == null || received < total) {
        final end = received + chunkSize - 1;
        final requestUri = rangeInQuery
            ? uri.replace(
                queryParameters: {
                  ...uri.queryParameters,
                  'range': '$received-$end',
                },
              )
            : uri;
        final response = await _dio.getUri<ResponseBody>(
          requestUri,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ...source.headers,
              if (!rangeInQuery) 'Range': 'bytes=$received-$end',
            },
            validateStatus: (s) => s != null && (s < 300 || s == 416),
          ),
        );

        final status = response.statusCode!;
        if (status == 416) {
          // Pedimos más allá del final: el .part ya estaba completo.
          total = received;
          break;
        }

        final fullBodyIgnoringRange = status == 200 && !rangeInQuery;
        if (fullBodyIgnoringRange && received > 0) {
          // El servidor no soporta rangos: empezamos de cero.
          await sink.flush();
          await part.writeAsBytes(const [], flush: true);
          received = 0;
        }
        total ??= _totalFrom(response, received, fullBodyIgnoringRange);

        var chunkBytes = 0;
        await for (final data in response.data!.stream) {
          sink.add(data);
          chunkBytes += data.length;
          received += data.length;
          _reportProgress(key, received, total);
        }

        if (fullBodyIgnoringRange) {
          total ??= received;
          break;
        }
        if (chunkBytes == 0) {
          // Sin datos y sin tamaño conocido: asumimos fin de archivo.
          total ??= received;
          break;
        }
        // Sin tamaño conocido, un trozo incompleto marca el final.
        if (total == null && chunkBytes < chunkSize) total = received;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  int? _totalFrom(Response<ResponseBody> response, int offset, bool full) {
    final range = response.headers.value('content-range');
    if (range != null) {
      final total = int.tryParse(range.split('/').last);
      if (total != null) return total;
    }
    final length = int.tryParse(response.headers.value('content-length') ?? '');
    if (length == null) return null;
    return full ? length : null;
  }

  void _reportProgress(String key, int received, int? total) {
    final task = _tasks[key];
    if (task == null) return;
    // Máximo ~5 actualizaciones por segundo para no saturar la UI.
    final now = DateTime.now();
    final last = _lastProgressEmit[key];
    final done = total != null && received >= total;
    if (!done &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastProgressEmit[key] = now;
    _set(key, task.copyWith(receivedBytes: received, totalBytes: total));
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  String _extensionFor(Uri url) {
    final mime = url.queryParameters['mime'] ?? '';
    if (mime.contains('webm')) return 'webm';
    if (mime.contains('mpeg')) return 'mp3';
    if (mime.contains('mp4')) return 'm4a';
    final path = url.path.toLowerCase();
    for (final ext in const ['mp3', 'm4a', 'aac', 'ogg', 'opus', 'webm']) {
      if (path.endsWith('.$ext')) return ext;
    }
    return 'm4a';
  }

  String _describe(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout => 'Sin conexión',
    DioExceptionType.receiveTimeout => 'La descarga se ha quedado parada',
    DioExceptionType.badResponse =>
      'El servidor respondió ${e.response?.statusCode}',
    _ => e.message ?? 'Error de descarga',
  };

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  void _set(String key, DownloadTask task) {
    _tasks[key] = task;
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(tasks);
  }
}
