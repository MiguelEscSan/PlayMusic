import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/favorites/domain/i_liked_playlist_sync.dart';

/// Alterna el "me gusta" de una canción y lo refleja en "Me encanta".
///
/// 1. Guarda la canción (los resultados de búsqueda llegan sin id) y decide
///    con el estado de la BD, no con el de [Song], que puede estar desfasado.
/// 2. Marca o desmarca el "me gusta" (`likedAt` sellado con el reloj).
/// 3. Añade o quita la canción de la playlist "Me encanta".
///
/// Un fallo en 1 o 2 se devuelve tal cual (no cambió nada). Un fallo en 3
/// llega como `Err(LikedPlaylistSyncFailure)` con la canción ya actualizada:
/// el "me gusta" sí cambió (F5), así que quien llama debe refrescar igual.
final class ToggleLikeUseCase {
  ToggleLikeUseCase(
    this._songs,
    this._likedPlaylist, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ISongRepository _songs;
  final ILikedPlaylistSync _likedPlaylist;
  final DateTime Function() _now;

  Future<Result<Song>> call(Song song) async {
    final Song saved;
    switch (await _songs.save(song)) {
      case Ok(:final value):
        saved = value;
      case Err(:final failure):
        return Err(failure);
    }

    final liked = !saved.isLiked;
    if (await _songs.setLiked(saved.id, liked: liked) case Err(
      :final failure,
    )) {
      return Err(failure);
    }
    final updated = liked
        ? saved.copyWith(likedAt: _now())
        : saved.copyWith(clearLiked: true);

    return switch (await _likedPlaylist.sync(updated)) {
      Ok() => Ok(updated),
      Err(:final failure) => Err(
        LikedPlaylistSyncFailure(updated, cause: failure),
      ),
    };
  }
}
