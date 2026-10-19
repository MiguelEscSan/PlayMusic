import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/result.dart';

/// Quita de una playlist la canción que ocupa la posición [index] (una
/// playlist puede tener la misma canción en varias posiciones).
final class RemoveSongAtUseCase {
  const RemoveSongAtUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<Unit>> call(String playlistId, int index) =>
      _playlists.removeSongAt(playlistId, index);
}
