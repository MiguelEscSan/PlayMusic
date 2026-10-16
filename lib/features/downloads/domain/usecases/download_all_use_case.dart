import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/domain/i_download_service.dart';

/// Encola la descarga de las canciones que aún no están descargadas, en
/// orden. Una excepción detiene el resto y llega como `Err(StorageFailure)`.
final class DownloadAllUseCase {
  const DownloadAllUseCase(this._downloads);

  final IDownloadService _downloads;

  Future<Result<Unit>> call(List<Song> songs) => guard(
    () async {
      for (final song in songs.where((s) => !s.isDownloaded)) {
        await _downloads.download(song);
      }
      return unit;
    },
    onError: (e, st) => StorageFailure(
      'No se pudieron encolar las descargas',
      cause: e,
      stackTrace: st,
    ),
  );
}
