import 'package:sponify/core/error/result.dart';

/// Portadas personalizadas de las playlists: copia la imagen elegida y
/// borra la anterior al cambiarla, quitarla o borrar la playlist. Nunca
/// lanza: un error de archivo llega como `Err(StorageFailure)`.
abstract interface class IPlaylistCoverService {
  /// Usa como portada una copia de la imagen [sourcePath].
  Future<Result<Unit>> setFromFile(String playlistId, String sourcePath);

  /// Vuelve a la portada automática.
  Future<Result<Unit>> clear(String playlistId);

  /// Borra la playlist y su portada personalizada.
  Future<Result<Unit>> deletePlaylist(String playlistId);
}
