import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Mueve una canción de [oldIndex] a [newIndex] (posición final ya
/// corregida, no la semántica de hueco de `ReorderableListView`).
final class MoveSongInPlaylistUseCase {
  const MoveSongInPlaylistUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<Unit>> call(String playlistId, int oldIndex, int newIndex) =>
      _playlists.moveSong(playlistId, oldIndex, newIndex);
}
