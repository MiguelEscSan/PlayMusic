import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/settings/settings_providers.dart';
import '../../downloads/data/download_manager.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../data/liked_playlist.dart';

/// Sincroniza los "me gusta" con la playlist "Me encanta".
final likedPlaylistProvider = Provider<LikedPlaylist>(
  (ref) => LikedPlaylist(
    playlists: ref.watch(playlistRepositoryProvider),
    songs: ref.watch(songRepositoryProvider),
    settings: ref.watch(settingsDaoProvider),
  ),
);

/// Canciones con "me gusta", la última marcada primero. Se refresca sola
/// con cada cambio en la tabla `songs`.
final likedSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(songDaoProvider);
  final repository = ref.watch(songRepositoryProvider);
  // Un Err se lanza como AsyncError; en la fase 3 lo tratarán los notifiers.
  Future<List<Song>> load() async => unwrapOrThrow(await repository.getLiked());
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
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
