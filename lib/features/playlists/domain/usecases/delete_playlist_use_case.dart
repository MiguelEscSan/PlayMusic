import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/domain/i_playlist_cover_service.dart';

/// Borra la playlist y su portada personalizada.
final class DeletePlaylistUseCase {
  const DeletePlaylistUseCase(this._covers);

  final IPlaylistCoverService _covers;

  Future<Result<Unit>> call(String id) => guardResult(
    () => _covers.deletePlaylist(id),
    onError: (e, st) => StorageFailure(
      'No se pudo borrar la playlist',
      cause: e,
      stackTrace: st,
    ),
  );
}
