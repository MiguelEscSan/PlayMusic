import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/playlists/domain/remote_playlist.dart';

/// Busca en el catálogo de Koda (p. ej. YouTube) la canción que corresponde
/// a una pista de otro servicio. Nunca lanza:
/// - `Ok(song)`: la mejor coincidencia aceptable.
/// - `Ok(null)`: no hay ninguna coincidencia fiable; la pista se omite.
/// - `Err(NetworkFailure)`: no se pudo buscar.
abstract interface class ITrackMatcher {
  Future<Result<Song?>> match(RemoteTrack track);
}
