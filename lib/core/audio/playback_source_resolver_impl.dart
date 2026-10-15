import 'dart:io';

import '../models/song.dart';
import 'playback_source.dart';
import 'stream_url_provider.dart';

typedef LocalFileMissingCallback = Future<void> Function(Song song);
typedef FileProbe = Future<bool> Function(String path);

/// Implementación por defecto del contrato de [PlaybackSourceResolver]:
/// archivo local si existe; si no, URL de streaming válida (cacheada o
/// pedida de nuevo al origen).
class DefaultPlaybackSourceResolver implements PlaybackSourceResolver {
  DefaultPlaybackSourceResolver({
    required List<StreamUrlProvider> providers,
    this.onLocalFileMissing,
    FileProbe? fileProbe,
    DateTime Function()? clock,
  }) : _providers = {for (final p in providers) p.source: p},
       _fileProbe = fileProbe ?? _defaultFileProbe,
       _clock = clock ?? DateTime.now;

  final Map<SongSource, StreamUrlProvider> _providers;
  final FileProbe _fileProbe;
  final DateTime Function() _clock;

  /// Se invoca cuando `song.localPath` apunta a un archivo que ya no está.
  /// En el Paso 3 lo conectamos al repositorio para limpiar la BD.
  final LocalFileMissingCallback? onLocalFileMissing;

  /// URLs resueltas en esta sesión, por `source:sourceId`. Evita volver a
  /// pedir el manifest a YouTube cada vez que se repite una canción.
  final Map<String, Uri> _urlCache = {};

  /// Margen de seguridad: una URL que caduca en menos de esto se renueva,
  /// para que no expire a mitad de la canción.
  static const _expiryMargin = Duration(minutes: 10);

  static Future<bool> _defaultFileProbe(String path) async {
    final file = File(path);
    return await file.exists() && await file.length() > 0;
  }

  @override
  Future<PlaybackSource> resolve(Song song, {bool forceRefresh = false}) async {
    // 1-2. Archivo local.
    final localPath = song.localPath;
    if (localPath != null) {
      if (await _fileProbe(localPath)) return LocalFileSource(localPath);
      await onLocalFileMissing?.call(song);
    }

    // 3. URL cacheada (en memoria o la que trae la canción).
    final key = '${song.source.name}:${song.sourceId}';
    if (!forceRefresh) {
      final cached = _urlCache[key] ?? _tryParse(song.streamUrl);
      if (cached != null && _isFresh(cached)) {
        return RemoteStreamSource(cached);
      }
    }

    // 4. URL nueva desde el origen.
    final provider = _providers[song.source];
    if (provider == null) {
      // Orígenes con URL estable (p. ej. Jamendo) no necesitan provider.
      final direct = _tryParse(song.streamUrl);
      if (direct != null) return RemoteStreamSource(direct);
      throw SongUnavailableException(song, 'sin archivo local ni URL');
    }

    try {
      final fresh = await provider.fetchStreamUrl(song.sourceId);
      _urlCache[key] = fresh;
      return RemoteStreamSource(fresh);
    } on SocketException {
      // 5. Sin red y sin archivo.
      throw SongUnavailableException(song, 'sin conexión');
    } on YoutubeBlockedException {
      rethrow; // el reproductor muestra su mensaje tal cual
    } catch (e) {
      throw SongUnavailableException(song, e.toString());
    }
  }

  /// Las URLs de googlevideo llevan `expire=<unix seconds>`. Si no hay ese
  /// parámetro asumimos que la URL no caduca.
  bool _isFresh(Uri uri) {
    final expire = int.tryParse(uri.queryParameters['expire'] ?? '');
    if (expire == null) return true;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
    return expiresAt.isAfter(_clock().add(_expiryMargin));
  }

  static Uri? _tryParse(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    return (uri != null && uri.hasScheme) ? uri : null;
  }
}
