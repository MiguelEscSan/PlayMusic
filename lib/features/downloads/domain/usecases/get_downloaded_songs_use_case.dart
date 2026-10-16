import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Canciones descargadas, las más recientes primero.
final class GetDownloadedSongsUseCase {
  const GetDownloadedSongsUseCase(this._songs);

  final ISongRepository _songs;

  Future<Result<List<Song>>> call() => _songs.getDownloaded();
}
