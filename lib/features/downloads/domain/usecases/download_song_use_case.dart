import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/domain/i_download_service.dart';

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
