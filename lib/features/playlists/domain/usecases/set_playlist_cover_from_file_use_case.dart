import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/domain/i_playlist_cover_service.dart';

/// Usa como portada de la playlist una copia de la imagen [imagePath].
final class SetPlaylistCoverFromFileUseCase {
  const SetPlaylistCoverFromFileUseCase(this._covers);

  final IPlaylistCoverService _covers;

  Future<Result<Unit>> call(String id, String imagePath) => guardResult(
    () => _covers.setFromFile(id, imagePath),
    onError: (e, st) => StorageFailure(
      'No se pudo cambiar la portada',
      cause: e,
      stackTrace: st,
    ),
  );
}
