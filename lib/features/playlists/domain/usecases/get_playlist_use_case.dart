import 'package:koda/core/domain/entities/playlist.dart';
import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/result.dart';

/// Una playlist con sus canciones. `Err(NotFoundFailure)` si no existe.
final class GetPlaylistUseCase {
  const GetPlaylistUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<Playlist>> call(String id) => _playlists.findById(id);
}
