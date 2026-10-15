import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/song.dart';
import '../../downloads/data/download_manager.dart';
import '../../downloads/presentation/downloads_providers.dart';

/// Canciones con "me gusta", la última marcada primero. Se refresca sola
/// con cada cambio en la tabla `songs`.
final likedSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(songDaoProvider);
  yield await dao.liked();
  await for (final _ in dao.changes) {
    yield await dao.liked();
  }
});

/// Claves (`source:sourceId`) de las favoritas. Sirve para pintar el corazón
/// de cualquier canción (p. ej. un resultado de búsqueda sin id o la que
/// suena) sin fiarse de su `likedAt`, que puede estar desfasado.
final likedKeysProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(likedSongsProvider).value ?? const [];
  return {for (final s in songs) DownloadManager.keyOf(s)};
});

final isLikedProvider = Provider.family<bool, Song>(
  (ref, song) =>
      ref.watch(likedKeysProvider).contains(DownloadManager.keyOf(song)),
);
