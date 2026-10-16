import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../player/presentation/player_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../data/lyrics_repository.dart';

/// Canción que suena ahora (solo cambia cuando cambia la canción, no en
/// cada evento del reproductor).
final lyricsSongProvider = Provider<Song?>(
  (ref) =>
      ref.watch(playerSnapshotProvider.select((s) => s.value?.currentSong)),
);

/// Letra de una canción. `ref.invalidate` sobre ella = "Reintentar".
/// Sin reintento automático: el usuario decide con el botón.
final lyricsProvider = FutureProvider.autoDispose.family<Lyrics, Song>(
  (ref, song) => ref.watch(lyricsRepositoryProvider).getLyrics(song),
  retry: (retryCount, error) => null,
);
