import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/song_dao.dart';
import '../../../core/domain/entities/song.dart';
import '../data/download_manager.dart';
import '../domain/download_task.dart';
import 'downloads_notifier.dart';

export 'downloads_notifier.dart';

/// Se sobrescriben en `main()` con las instancias de `bootstrap()`. Solo lo
/// usa `songRepositoryProvider`: la UI pasa por los notifiers.
final songDaoProvider = Provider<SongDao>(
  (ref) => throw UnimplementedError('songDaoProvider se define en main()'),
);

final downloadManagerProvider = Provider<DownloadManager>(
  (ref) =>
      throw UnimplementedError('downloadManagerProvider se define en main()'),
);

/// Todas las descargas activas o recientes.
final downloadTasksProvider = StreamProvider<Map<String, DownloadTask>>(
  (ref) => ref.watch(downloadManagerProvider).tasksStream,
);

/// Estado de descarga de una canción (botón de descarga en cada fila).
final downloadTaskProvider = Provider.family<DownloadTask?, Song>(
  (ref, song) =>
      ref.watch(downloadTasksProvider).value?[DownloadManager.keyOf(song)],
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
  return {for (final s in songs) DownloadManager.keyOf(s)};
});
