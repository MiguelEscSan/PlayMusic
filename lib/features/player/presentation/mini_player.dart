import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/audio/audio_providers.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final loading =
        snapshot.status == PlaybackStatus.loading ||
        snapshot.status == PlaybackStatus.buffering;
    final canSkipNext =
        snapshot.hasNext || snapshot.repeatMode == PlayerRepeatMode.all;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => openNowPlaying(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniProgress(total: song.duration),
            ClipRect(
              child: SwipeToSkip(
                canSkipNext: canSkipNext,
                canSkipPrevious: snapshot.hasPrevious,
                onNext: audio.skipToNext,
                onPrevious: audio.skipToPrevious,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'artwork',
                        child: ArtworkImage(
                          url: song.artworkUrl,
                          seed: song.title,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Row(
                              children: [
                                if (snapshot.isPlayingOffline) ...[
                                  Icon(
                                    Icons.offline_pin_rounded,
                                    size: 14,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    snapshot.errorMessage ?? song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: snapshot.errorMessage != null
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
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: canSkipNext ? audio.skipToNext : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
