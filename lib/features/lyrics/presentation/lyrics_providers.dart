import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_providers.dart';
import '../../../core/models/song.dart';
import '../data/lyrics_repository.dart';

/// Repositorio único para que la caché en memoria dure toda la sesión.
final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ),
  ),
);

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
