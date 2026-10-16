import '../../../core/domain/entities/song.dart';

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

/// Estado de una descarga, tal como lo pinta la UI.
class DownloadTask {
  const DownloadTask({
    required this.song,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes,
    this.error,
  });

  final Song song;
  final DownloadStatus status;
  final int receivedBytes;
  final int? totalBytes;
  final String? error;

  /// 0.0 – 1.0, o null si el servidor no informó del tamaño.
  double? get progress {
    if (status == DownloadStatus.completed) return 1.0;
    final total = totalBytes;
    if (total == null || total == 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  DownloadTask copyWith({
    Song? song,
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? error,
  }) => DownloadTask(
    song: song ?? this.song,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    error: error ?? this.error,
  );
}
