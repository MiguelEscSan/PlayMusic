import '../domain/download_task.dart';

/// Cálculo de progreso solo para la UI; el dominio no lo conoce.
extension DownloadTaskProgress on DownloadTask {
  /// 0.0 – 1.0, o null si el servidor no informó del tamaño.
  double? get progress {
    if (status == DownloadStatus.completed) return 1.0;
    final total = totalBytes;
    if (total == null || total == 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}
