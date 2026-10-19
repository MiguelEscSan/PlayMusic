import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/result.dart';

/// Añade una canción al final de una playlist.
///
/// `Ok(true)` si se añadió, `Ok(false)` si ya estaba en la playlist.
final class AddSongToPlaylistUseCase {
  const AddSongToPlaylistUseCase(this._repository);

  final IPlaylistRepository _repository;

  Future<Result<bool>> call(String playlistId, Song song) =>
      _repository.addSong(playlistId, song);
}
