import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/i_download_service.dart';

/// Encola la descarga de una canción. `Ok` con la canción tal como quedó en
/// la BD; los fallos de la propia descarga se ven en su tarea. Una
/// excepción al encolar llega como `Err(StorageFailure)`.
final class DownloadSongUseCase {
  const DownloadSongUseCase(this._downloads);

  final IDownloadService _downloads;

  Future<Result<Song>> call(Song song) => guard(
    () => _downloads.download(song),
    onError: (e, st) => StorageFailure(
      'No se pudo encolar la descarga',
      cause: e,
      stackTrace: st,
    ),
  );
}
