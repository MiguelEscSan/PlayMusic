import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/song_dao.dart';
import '../../../core/models/song.dart';
import '../data/download_manager.dart';
import '../domain/download_task.dart';

/// Se sobrescriben en `main()` con las instancias de `bootstrap()`.
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

/// Canciones descargadas; se refresca sola al descargar o borrar.
final downloadedSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(songDaoProvider);
  yield await dao.downloaded();
  await for (final _ in dao.changes) {
    yield await dao.downloaded();
  }
});

/// Espacio ocupado por las descargas, en bytes.
final downloadsSizeProvider = StreamProvider<int>((ref) async* {
  final dao = ref.watch(songDaoProvider);
  yield await dao.downloadedBytes();
  await for (final _ in dao.changes) {
    yield await dao.downloadedBytes();
  }
});

/// Claves (`source:sourceId`) de las canciones descargadas, para marcar
/// como descargados los resultados de búsqueda sin consultar la BD.
final downloadedKeysProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value ?? const [];
  return {for (final s in songs) DownloadManager.keyOf(s)};
});
