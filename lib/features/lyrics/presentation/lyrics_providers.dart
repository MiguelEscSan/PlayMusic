import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../../../di/providers.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/lyrics.dart';

/// Canción que suena ahora (solo cambia cuando cambia la canción, no en
/// cada evento del reproductor).
final lyricsSongProvider = Provider<Song?>(
  (ref) =>
      ref.watch(playerSnapshotProvider.select((s) => s.value?.currentSong)),
);

/// Letra de una canción (`GetLyricsUseCase`). Un `Err` se lanza como su
/// `Failure` tipado. `ref.invalidate` sobre ella = "Reintentar".
/// Sin reintento automático: el usuario decide con el botón.
final lyricsProvider = FutureProvider.autoDispose.family<Lyrics, Song>(
  (ref, song) async =>
      switch (await ref.watch(getLyricsUseCaseProvider)(song)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
  retry: (retryCount, error) => null,
);
