import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Todas las playlists.
final class GetPlaylistsUseCase {
  const GetPlaylistsUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<List<Playlist>>> call() => _playlists.getAll();
}
