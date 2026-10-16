import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';

/// Progreso de una importación: canciones procesadas de [total].
typedef ImportProgress = void Function(int done, int total);

/// Resultado de una importación.
final class ImportResult {
  const ImportResult({
    required this.playlistId,
    required this.imported,
    required this.skipped,
  });

  final String playlistId;
  final int imported;

  /// Vídeos omitidos: no disponibles como canción o repetidos.
  final int skipped;
}

/// El texto pegado no es un enlace de playlist de YouTube.
final class InvalidPlaylistLinkFailure extends ValidationFailure {
  const InvalidPlaylistLinkFailure()
    : super('El enlace no es de una playlist de YouTube');
}

/// La playlist no tiene ninguna canción que se pueda importar.
final class EmptyPlaylistFailure extends ValidationFailure {
  const EmptyPlaylistFailure()
    : super('La playlist no tiene canciones que importar');
}

/// Crea una playlist local a partir de una remota, con el mismo título y
/// las canciones en el mismo orden. Nunca lanza:
/// - `Err(InvalidPlaylistLinkFailure)` / `Err(EmptyPlaylistFailure)`: no se
///   crea ninguna playlist.
/// - `Err(NetworkFailure)`: no se pudo leer la playlist remota.
/// - Un fallo al guardar llega como su `Err` (la playlist puede quedar a
///   medias).
abstract interface class IPlaylistImporter {
  Future<Result<ImportResult>> importFromUrl(
    String urlOrId, {
    ImportProgress? onProgress,
  });
}
