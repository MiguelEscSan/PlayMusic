import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/i_download_service.dart';

/// Borra el archivo descargado de una canción; sigue en sus playlists para
/// escucharla en streaming. Devuelve la canción sin archivo local.
final class DeleteDownloadUseCase {
  const DeleteDownloadUseCase(this._downloads);

  final IDownloadService _downloads;

  Future<Result<Song>> call(Song song) => guardResult(
    () => _downloads.delete(song),
    onError: (e, st) => StorageFailure(
      'No se pudo borrar la descarga',
      cause: e,
      stackTrace: st,
    ),
  );
}
