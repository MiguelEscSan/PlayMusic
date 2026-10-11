/// 3:07 · 1:02:03
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// 850 KB · 12,4 MB · 1,2 GB
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} GB';
}

/// "1 canción" · "12 canciones"
String songCount(int n) => n == 1 ? '1 canción' : '$n canciones';

/// "1 descargada" · "3 descargadas"
String downloadedLabel(int n) => n == 1 ? '1 descargada' : '$n descargadas';
