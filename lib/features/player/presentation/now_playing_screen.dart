import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/download_button.dart';
import '../../favorites/presentation/like_button.dart';
import '../../lyrics/presentation/lyrics_screen.dart';
import '../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../sleep_timer/sleep_timer_sheet.dart';
import 'queue_sheet.dart';

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

/// Pantalla completa del reproductor.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playerSnapshotProvider).value;
    final song = snapshot?.currentSong;
    final theme = Theme.of(context);

    if (snapshot == null || song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No hay nada sonando')),
      );
    }

    final audio = ref.read(audioPlayerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          snapshot.isPlayingOffline
              ? 'Sin conexión · archivo local'
              : 'Streaming',
          style: theme.textTheme.labelLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Letra',
            icon: const Icon(Icons.lyrics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LyricsScreen()),
            ),
          ),
          const SleepTimerButton(),
          IconButton(
            tooltip: 'Añadir a una playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => showAddToPlaylistSheet(context, song),
          ),
          IconButton(
            tooltip: 'Cola',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight;
            final artSize =
                (wide
                        ? constraints.maxHeight * 0.75
                        : constraints.maxWidth - 64)
                    .clamp(120.0, 420.0);

            final artwork = Hero(
              tag: 'artwork',
              child: ArtworkImage(
                url: song.artworkUrl,
                seed: song.title,
                size: artSize,
                radius: 16,
              ),
            );

            final controls = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LikeButton(song: song),
                      DownloadButton(song: song, size: 28),
                    ],
                  ),
                  if (snapshot.errorMessage case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _SeekBar(total: song.duration),
                  const SizedBox(height: 8),
                  _TransportControls(snapshot: snapshot, audio: audio),
                ],
              ),
            );

            if (wide) {
              return Row(
                children: [
                  Expanded(child: Center(child: artwork)),
                  Expanded(child: Center(child: controls)),
                ],
              );
            }
            return Column(
              children: [
                const Spacer(),
                artwork,
                const Spacer(),
                controls,
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.snapshot, required this.audio});

  final PlayerSnapshot snapshot;
  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading =
        snapshot.status == PlaybackStatus.loading ||
        snapshot.status == PlaybackStatus.buffering;

    final (repeatIcon, nextRepeat) = switch (snapshot.repeatMode) {
      PlayerRepeatMode.off => (Icons.repeat_rounded, PlayerRepeatMode.all),
      PlayerRepeatMode.all => (Icons.repeat_on_rounded, PlayerRepeatMode.one),
      PlayerRepeatMode.one => (
        Icons.repeat_one_on_rounded,
        PlayerRepeatMode.off,
      ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Aleatorio',
          onPressed: () => audio.setShuffle(!snapshot.shuffleEnabled),
          icon: Icon(
            Icons.shuffle_rounded,
            color: snapshot.shuffleEnabled ? scheme.primary : null,
          ),
        ),
        IconButton(
          tooltip: 'Anterior',
          iconSize: 40,
          onPressed: audio.skipToPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        SizedBox.square(
          dimension: 72,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                )
              : IconButton.filled(
                  tooltip: snapshot.isPlaying ? 'Pausa' : 'Reproducir',
                  iconSize: 40,
                  onPressed: audio.togglePlayPause,
                  icon: Icon(
                    snapshot.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          iconSize: 40,
          onPressed:
              snapshot.hasNext || snapshot.repeatMode == PlayerRepeatMode.all
              ? audio.skipToNext
              : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        IconButton(
          tooltip: 'Repetir',
          onPressed: () => audio.setRepeat(nextRepeat),
          icon: Icon(
            repeatIcon,
            color: snapshot.repeatMode == PlayerRepeatMode.off
                ? null
                : scheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Barra de posición. Mientras se arrastra muestra la posición del dedo
/// y solo hace seek al soltar.
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.total});

  final Duration total;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final totalMs = widget.total.inMilliseconds.toDouble();
    final max = totalMs <= 0 ? 1.0 : totalMs;
    final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
      0.0,
      max,
    );
    final style = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        Slider(
          value: value,
          max: max,
          onChanged: (v) => setState(() => _dragValue = v),
          onChangeEnd: (v) {
            ref
                .read(audioPlayerServiceProvider)
                .seek(Duration(milliseconds: v.round()));
            setState(() => _dragValue = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: value.round())),
                style: style,
              ),
              Text(formatDuration(widget.total), style: style),
            ],
          ),
        ),
      ],
    );
  }
}
