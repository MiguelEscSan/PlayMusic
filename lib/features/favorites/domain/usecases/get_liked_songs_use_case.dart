import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_song_repository.dart';
import 'package:koda/core/error/result.dart';

/// Canciones con "me gusta", la última marcada primero.
final class GetLikedSongsUseCase {
  const GetLikedSongsUseCase(this._songs);

  final ISongRepository _songs;

  Future<Result<List<Song>>> call() => _songs.getLiked();
}
