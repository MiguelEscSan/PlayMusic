import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/result.dart';

/// Deshace un "quitar": vuelve a poner [song] en la posición [position].
///
/// La BD solo sabe añadir al final, así que la canción se añade (queda en
/// [appendedAt], la longitud de la playlist antes de añadirla) y, si hace
/// falta, se recoloca. `Ok(false)` si ya estaba en la playlist (no se
/// mueve nada). Si no se puede recolocar devuelve ese `Err`, aunque la
/// canción ya se haya añadido al final.
final class RestoreSongAtUseCase {
  const RestoreSongAtUseCase(this._playlists);

  final IPlaylistRepository _playlists;

  Future<Result<bool>> call(
    String playlistId,
    Song song, {
    required int position,
    required int appendedAt,
  }) async {
    switch (await _playlists.addSong(playlistId, song)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Ok(false);
      case Ok(value: true):
        if (position == appendedAt) return const Ok(true);
        final moved = await _playlists.moveSong(
          playlistId,
          appendedAt,
          position,
        );
        return moved.map((_) => true);
    }
  }
}
