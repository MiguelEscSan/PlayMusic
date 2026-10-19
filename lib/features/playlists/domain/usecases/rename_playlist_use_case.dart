import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/result.dart';

/// Cambia el nombre de una playlist.
final class RenamePlaylistUseCase {
  const RenamePlaylistUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<Unit>> call(String id, String name) =>
      _playlists.rename(id, name);
}
