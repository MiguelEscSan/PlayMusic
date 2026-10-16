import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/features/downloads/domain/i_download_service.dart';

/// Avisa cada vez que el archivo local de una canción aparece o desaparece
/// (descarga terminada, borrada o archivo perdido). Las listas que muestran
/// `localPath` se recargan con él.
final class WatchDownloadsChangedUseCase {
  const WatchDownloadsChangedUseCase(this._downloads);

  final IDownloadService _downloads;

  Stream<Song> call() => _downloads.downloadsChanged;
}
