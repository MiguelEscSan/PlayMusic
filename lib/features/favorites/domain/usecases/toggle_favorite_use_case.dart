import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Alterna el "me gusta" de una canción.
///
/// Devuelve la canción actualizada (con `likedAt` sellado con el reloj o
/// borrado). Si el repositorio falla, propaga el `Failure` sin cambios.
final class ToggleFavoriteUseCase {
  ToggleFavoriteUseCase(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ISongRepository _repository;
  final DateTime Function() _now;

  Future<Result<Song>> call(Song song) async {
    final liked = !song.isLiked;
    final result = await _repository.setLiked(song.id, liked: liked);
    return result.map(
      (_) => liked
          ? song.copyWith(likedAt: _now())
          : song.copyWith(clearLiked: true),
    );
  }
}
