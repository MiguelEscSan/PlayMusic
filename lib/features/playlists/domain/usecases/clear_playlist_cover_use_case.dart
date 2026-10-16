import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/domain/i_playlist_cover_service.dart';

/// Vuelve a la portada automática (la carátula de la primera canción).
final class ClearPlaylistCoverUseCase {
  const ClearPlaylistCoverUseCase(this._covers);

  final IPlaylistCoverService _covers;

  Future<Result<Unit>> call(String id) => guardResult(
    () => _covers.clear(id),
    onError: (e, st) => StorageFailure(
      'No se pudo quitar la portada',
      cause: e,
      stackTrace: st,
    ),
  );
}
