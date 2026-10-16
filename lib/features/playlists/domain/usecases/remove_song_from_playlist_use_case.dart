import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Quita una canción de una playlist.
///
/// `Ok(true)` si se quitó, `Ok(false)` si no estaba en la playlist.
final class RemoveSongFromPlaylistUseCase {
  const RemoveSongFromPlaylistUseCase(this._repository);

  final IPlaylistRepository _repository;

  Future<Result<bool>> call(String playlistId, String songId) =>
      _repository.removeSong(playlistId, songId);
}
