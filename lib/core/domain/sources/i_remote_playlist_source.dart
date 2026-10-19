import 'package:koda/core/domain/entities/song.dart';

/// Una playlist leída de un origen: su título y sus vídeos en orden. Cada
/// elemento que no parezca una canción (directo, sin duración…) llega como
/// null, para contarlo como omitido.
typedef RemoteSongPlaylist = ({String title, List<Song?> songs});

/// Lee playlists públicas de un origen cuyas canciones se reproducen
/// directamente (p. ej. YouTube).
abstract interface class IRemotePlaylistSource {
  /// Id de playlist a partir del enlace completo o del id suelto; null si
  /// no es válido.
  String? parsePlaylistId(String urlOrId);

  /// Lee la playlist [playlistId], como mucho [maxSongs] canciones. Puede
  /// lanzar si falla la red.
  Future<RemoteSongPlaylist> fetch(String playlistId, {required int maxSongs});
}
