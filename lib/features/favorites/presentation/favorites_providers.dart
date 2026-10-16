import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/domain/song_key.dart';
import 'liked_songs_notifier.dart';

export 'liked_songs_notifier.dart';

/// Claves (`source:sourceId`) de las favoritas. Sirve para pintar el corazón
/// de cualquier canción (p. ej. un resultado de búsqueda sin id o la que
/// suena) sin fiarse de su `likedAt`, que puede estar desfasado.
final likedKeysProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(likedSongsProvider).value ?? const [];
  return {for (final s in songs) songKey(s)};
});

final isLikedProvider = Provider.family<bool, Song>(
  (ref, song) => ref.watch(likedKeysProvider).contains(songKey(song)),
);
