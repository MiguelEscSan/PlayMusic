import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Crea una playlist vacía.
final class CreatePlaylistUseCase {
  const CreatePlaylistUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<Playlist>> call(String name) => _playlists.create(name);
}
