import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/domain/song_key.dart';
import '../../../di/providers.dart';
import '../domain/download_task.dart';
import 'downloads_notifier.dart';

export 'downloads_notifier.dart';

/// Todas las descargas activas o recientes, por [songKey].
final downloadTasksProvider = StreamProvider<Map<String, DownloadTask>>(
  (ref) => ref.watch(watchDownloadTasksUseCaseProvider)(),
);

/// Estado de descarga de una canción (botón de descarga en cada fila).
final downloadTaskProvider = Provider.family<DownloadTask?, Song>(
  (ref, song) => ref.watch(downloadTasksProvider).value?[songKey(song)],
);

/// Espacio ocupado por las descargas, en bytes (0 mientras cargan o si no
/// se pudieron leer).
final downloadsSizeProvider = Provider<int>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value ?? const [];
  return songs.fold(0, (sum, s) => sum + (s.fileSizeBytes ?? 0));
});

/// Claves (`source:sourceId`) de las canciones descargadas, para marcar
/// como descargados los resultados de búsqueda sin consultar la BD.
final downloadedKeysProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value ?? const [];
  return {for (final s in songs) songKey(s)};
});
