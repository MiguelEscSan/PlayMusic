import '../models/song.dart';

/// Resultado de decidir CÓMO se reproduce una [Song].
/// La capa de audio (Paso 2) lo traduce a `AudioSource.file` o
/// `AudioSource.uri` de just_audio; el resto de la app nunca ve just_audio.
sealed class PlaybackSource {
  const PlaybackSource();
}

/// El archivo existe en disco: reproducción offline, cero datos móviles.
final class LocalFileSource extends PlaybackSource {
  const LocalFileSource(this.filePath);
  final String filePath;
}

/// Streaming. [headers] permite pasar User-Agent u otras cabeceras que
/// algunos orígenes exigen.
final class RemoteStreamSource extends PlaybackSource {
  const RemoteStreamSource(this.uri, {this.headers = const {}});
  final Uri uri;
  final Map<String, String> headers;
}

/// Decide la fuente de una canción. Contrato:
///  1. Si `song.localPath` != null y el archivo existe y no está vacío
///     -> [LocalFileSource].
///  2. Si `song.localPath` apunta a un archivo que ya no existe (el usuario
///     lo borró, se limpió el almacenamiento) -> marcar la canción como no
///     descargada en la BD y seguir al paso 3.
///  3. Si `song.streamUrl` es válida y no ha caducado -> [RemoteStreamSource].
///  4. Si no, pedir una URL fresca al origen (`song.source` + `song.sourceId`).
///  5. Sin archivo local y sin red -> lanzar [SongUnavailableException].
///
/// [forceRefresh] ignora cualquier URL cacheada; el reproductor lo usa para
/// reintentar cuando el servidor rechaza una URL que parecía válida (403).
abstract interface class PlaybackSourceResolver {
  Future<PlaybackSource> resolve(Song song, {bool forceRefresh = false});
}

class SongUnavailableException implements Exception {
  const SongUnavailableException(this.song, [this.reason]);
  final Song song;
  final String? reason;

  @override
  String toString() =>
      'SongUnavailableException: "${song.title}" no disponible'
      '${reason == null ? '' : ' ($reason)'}';
}
