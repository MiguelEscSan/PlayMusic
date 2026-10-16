import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/settings/settings_providers.dart';
import '../../downloads/data/download_manager.dart';
import '../data/liked_playlist.dart';
import 'liked_songs_notifier.dart';

export 'liked_songs_notifier.dart';

/// Sincroniza los "me gusta" con la playlist "Me encanta".
final likedPlaylistProvider = Provider<LikedPlaylist>(
  (ref) => LikedPlaylist(
    playlists: ref.watch(playlistRepositoryProvider),
    songs: ref.watch(songRepositoryProvider),
    settings: ref.watch(settingsDaoProvider),
  ),
);

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
