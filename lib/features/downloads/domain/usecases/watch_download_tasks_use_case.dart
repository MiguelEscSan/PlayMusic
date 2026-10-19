import 'package:koda/features/downloads/domain/download_task.dart';
import 'package:koda/features/downloads/domain/i_download_service.dart';

/// Estado de todas las descargas activas o recientes, por `songKey`.
final class WatchDownloadTasksUseCase {
  const WatchDownloadTasksUseCase(this._downloads);

  final IDownloadService _downloads;

  Stream<Map<String, DownloadTask>> call() => _downloads.tasksStream;
}
