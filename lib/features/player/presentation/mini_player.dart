import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../../../shared/widgets/artwork_image.dart';
import 'now_playing_screen.dart';
import 'swipe_to_skip.dart';

/// Barra inferior con la canción actual. Toca para abrir el reproductor;
/// desliza a la izquierda o a la derecha para cambiar de canción.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playerSnapshotProvider).value;
    final song = snapshot?.currentSong;
    if (snapshot == null || song == null) return const SizedBox.shrink();

    final audio = ref.read(audioPlayerServiceProvider);
    final loading =
        snapshot.status == PlaybackStatus.loading ||
        snapshot.status == PlaybackStatus.buffering;
    final nextSong = snapshot.nextSong;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => openNowPlaying(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniProgress(total: song.duration),
            Row(
              children: [
                // Solo carátula y textos se deslizan; los botones se quedan.
                Expanded(
                  child: SwipeToSkip(
                    current: song,
                    next: nextSong,
                    previous: snapshot.previousSong,
                    onNext: audio.skipToNext,
                    // Siempre a la anterior; ⏮ reinicia la canción tras 3 s.
                    onPrevious: () =>
                        audio.skipToIndex(snapshot.currentIndex! - 1),
                    itemBuilder: (context, item) =>
                        _MiniSong(song: item, snapshot: snapshot),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else
                  IconButton(
                    tooltip: snapshot.isPlaying ? 'Pausa' : 'Reproducir',
                    onPressed: audio.togglePlayPause,
                    icon: Icon(
                      snapshot.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: 'Siguiente',
                    onPressed: nextSong != null ? audio.skipToNext : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carátula y textos de una canción del carrusel. La que suena lleva el
/// Hero y los avisos (offline, error); las vecinas, solo el artista.
class _MiniSong extends StatelessWidget {
  const _MiniSong({required this.song, required this.snapshot});

  final Song song;
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCurrent = song.id == snapshot.currentSong?.id;
    final error = isCurrent ? snapshot.errorMessage : null;

    final artwork = ArtworkImage(
      url: song.artworkUrl,
      seed: song.title,
      size: 44,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
      child: Row(
        children: [
          isCurrent ? Hero(tag: 'artwork', child: artwork) : artwork,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge,
                ),
                Row(
                  children: [
                    if (isCurrent && snapshot.isPlayingOffline) ...[
                      Icon(
                        Icons.offline_pin_rounded,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        error ?? song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: error != null
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fina barra de progreso; se reconstruye sola con la posición.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.total});

  final Duration total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final value = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(value: value, minHeight: 2);
  }
}
