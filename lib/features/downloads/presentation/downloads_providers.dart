import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/song_dao.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/song.dart';
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
  final repository = ref.watch(songRepositoryProvider);
  // Un Err se lanza como AsyncError; en la fase 3 lo tratarán los notifiers.
  Future<List<Song>> load() async =>
      unwrapOrThrow(await repository.getDownloaded());
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
  }
});

/// Espacio ocupado por las descargas, en bytes.
final downloadsSizeProvider = StreamProvider<int>((ref) async* {
  final dao = ref.watch(songDaoProvider);
  final repository = ref.watch(songRepositoryProvider);
  // Un Err se lanza como AsyncError; en la fase 3 lo tratarán los notifiers.
  Future<int> load() async =>
      unwrapOrThrow(await repository.getDownloadedBytes());
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
  }
});

/// Claves (`source:sourceId`) de las canciones descargadas, para marcar
/// como descargados los resultados de búsqueda sin consultar la BD.
final downloadedKeysProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value ?? const [];
  return {for (final s in songs) DownloadManager.keyOf(s)};
});
