import 'package:koda/core/error/result.dart';
import 'package:koda/features/playlists/domain/remote_playlist.dart';

/// Lee una playlist pública de Spotify sin iniciar sesión. Nunca lanza:
/// - `Ok(RemotePlaylist)`: nombre y pistas leídas (puede ser solo una parte;
///   `totalCount` dice cuántas tiene en realidad, o null si no se sabe).
/// - `Err(NotFoundFailure)`: la playlist no existe o no es pública.
/// - `Err(NetworkFailure)`: no se pudo leer (red, o Spotify cambió su
///   página).
abstract interface class ISpotifyPlaylistSource {
  Future<Result<RemotePlaylist>> fetch(String playlistId);
}
