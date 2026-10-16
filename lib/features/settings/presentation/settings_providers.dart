import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloads/presentation/downloads_providers.dart';

export 'settings_notifier.dart';

/// Espacio ocupado por las descargas: bytes y número de canciones.
typedef StorageUsage = ({int bytes, int songs});

/// `null` mientras carga (o si las descargas no están disponibles).
final storageUsageProvider = Provider<StorageUsage?>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value;
  if (songs == null) return null;
  final bytes = songs.fold<int>(0, (sum, s) => sum + (s.fileSizeBytes ?? 0));
  return (bytes: bytes, songs: songs.length);
});
