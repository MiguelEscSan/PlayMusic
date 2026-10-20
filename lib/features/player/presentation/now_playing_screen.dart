import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/audio/koda_audio_handler.dart';
import '../../../di/providers.dart';
import 'player_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/download_button.dart';
import '../../favorites/presentation/like_button.dart';
import '../../lyrics/presentation/lyrics_screen.dart';
import '../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../sleep_timer/sleep_timer_sheet.dart';
import 'queue_sheet.dart';
import 'swipe_to_skip.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snapshot.isPlayingOffline
                  ? 'Sin conexión · archivo local'
                  : 'Streaming',
              style: theme.textTheme.labelLarge,
            ),
            // TEMP: diagnóstico del auto-avance. Quitar al terminar.
            Consumer(
              builder: (context, ref, _) {
                ref.watch(playerPositionProvider);
                final audio = ref.read(audioPlayerServiceProvider);
                return Text(
                  audio is KodaAudioHandler
                      ? audio.debugReadout()
                      : 'sin handler',
                  style: theme.textTheme.labelSmall,
                );
              },
            ),
          ],
        ),
        centerTitle: true,
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

            Widget coverOf(Song item) {
              final cover = AnimatedScale(
                scale: snapshot.isPlaying ? 1 : 0.86,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 60,
                        spreadRadius: -16,
                        offset: const Offset(0, 28),
                      ),
                    ],
                  ),
                  child: ArtworkImage(
                    url: item.artworkUrl,
                    seed: item.title,
                    size: artSize,
                    radius: 16,
                  ),
                ),
              );
              // Solo la que suena vuela desde el mini-player.
              return item.id == song.id
                  ? Hero(tag: 'artwork', child: cover)
                  : cover;
            }

            Widget titleOf(Song item) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.artist,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                LikeButton(song: item),
                DownloadButton(song: item, size: 28),
              ],
            );

            // Carrusel: deslizar cambia de canción y asoma la vecina.
            Widget carousel(Widget Function(Song item) builder) => SwipeToSkip(
              current: song,
              next: snapshot.nextSong,
              previous: snapshot.previousSong,
              onNext: () => ref.read(skipToNextUseCaseProvider)(),
              // Siempre a la anterior; ⏮ reinicia la canción tras 3 s.
              onPrevious: () =>
                  ref.read(skipToPreviousSongUseCaseProvider)(snapshot),
              itemBuilder: (_, item) => builder(item),
            );

            final controls = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En vertical el título va dentro del carrusel.
                  if (wide) titleOf(song),
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
                  _TransportControls(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _ActionRow(song: song),
                ],
              ),
            );

            if (wide) {
              return Row(
                children: [
                  Expanded(
                    child: carousel((item) => Center(child: coverOf(item))),
                  ),
                  Expanded(child: Center(child: controls)),
                ],
              );
            }
            // Toda la zona de carátula y título responde al deslizar.
            return Column(
              children: [
                Expanded(
                  child: carousel(
                    (item) => Column(
                      children: [
                        Expanded(child: Center(child: coverOf(item))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: titleOf(item),
                        ),
                      ],
                    ),
                  ),
                ),
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

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final loading =
        snapshot.status == PlaybackStatus.loading ||
        snapshot.status == PlaybackStatus.buffering;

    final repeatIcon = switch (snapshot.repeatMode) {
      PlayerRepeatMode.off => Icons.repeat_rounded,
      PlayerRepeatMode.all => Icons.repeat_on_rounded,
      PlayerRepeatMode.one => Icons.repeat_one_on_rounded,
    };
    void skipToNext() => ref.read(skipToNextUseCaseProvider)();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Aleatorio',
          onPressed: () => ref.read(toggleShuffleUseCaseProvider)(snapshot),
          icon: Icon(
            Icons.shuffle_rounded,
            color: snapshot.shuffleEnabled ? scheme.primary : null,
          ),
        ),
        IconButton(
          tooltip: 'Anterior',
          iconSize: 40,
          onPressed: () => ref.read(skipToPreviousUseCaseProvider)(),
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
                  onPressed: () => ref.read(togglePlayPauseUseCaseProvider)(),
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
              ? skipToNext
              : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        IconButton(
          tooltip: 'Repetir',
          onPressed: () => ref.read(cycleRepeatModeUseCaseProvider)(snapshot),
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

/// Fila de acciones secundarias, solo iconos, bajo los controles.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
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
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            max: max,
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              ref.read(seekUseCaseProvider)(Duration(milliseconds: v.round()));
              setState(() => _dragValue = null);
            },
          ),
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
