import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../features/player/presentation/player_providers.dart';
import '../../../core/domain/entities/song.dart';
import '../data/lrc_parser.dart';
import '../data/lyrics_repository.dart';
import 'lyrics_providers.dart';

/// Pantalla de letra de la canción actual. Si la canción cambia mientras
/// está abierta, carga la letra de la nueva.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(lyricsSongProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: song == null
            ? const Text('Letra')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
      ),
      body: song == null
          ? const Center(child: Text('No hay nada sonando'))
          : _LyricsBody(song: song),
    );
  }
}

class _LyricsBody extends ConsumerWidget {
  const _LyricsBody({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider(song));

    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: 'No se pudo cargar la letra',
        action: FilledButton.tonal(
          onPressed: () => ref.invalidate(lyricsProvider(song)),
          child: const Text('Reintentar'),
        ),
      ),
      data: (lyrics) => switch (lyrics) {
        SyncedLyrics(:final lines) => _SyncedLyricsView(
          // La key reinicia el scroll y el resaltado al cambiar de canción.
          key: ValueKey(song),
          lines: lines,
        ),
        PlainLyrics(:final text) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(height: 1.6),
          ),
        ),
        InstrumentalLyrics() => const _Message(
          icon: Icons.music_note_rounded,
          text: 'Canción instrumental',
        ),
        LyricsNotFound() => const _Message(
          icon: Icons.lyrics_outlined,
          text: 'No hay letra para esta canción',
        ),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Letra sincronizada: resalta la línea actual, la mantiene a la vista y
/// permite saltar a una línea tocándola.
class _SyncedLyricsView extends ConsumerStatefulWidget {
  const _SyncedLyricsView({super.key, required this.lines});

  final List<LyricLine> lines;

  @override
  ConsumerState<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<_SyncedLyricsView> {
  // Las letras rara vez pasan de unas decenas de líneas: se construyen
  // todas (Column) para que `ensureVisible` funcione con cualquier línea.
  late final List<GlobalKey> _keys = List.generate(
    widget.lines.length,
    (_) => GlobalKey(),
  );
  int _scrolledTo = -1;

  void _scrollTo(int index) {
    if (index < 0 || index == _scrolledTo) return;
    _scrolledTo = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lineContext = _keys[index].currentContext;
      if (lineContext == null || !mounted) return;
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final current = currentLineIndex(widget.lines, position);
    _scrollTo(current);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.lines.length; i++)
            LyricLineTile(
              key: _keys[i],
              text: widget.lines[i].text,
              isActive: i == current,
              onTap: () => ref
                  .read(audioPlayerServiceProvider)
                  .seek(widget.lines[i].time),
            ),
        ],
      ),
    );
  }
}

/// Una línea de la letra sincronizada. Pública para poder comprobar en los
/// tests cuál está resaltada.
class LyricLineTile extends StatelessWidget {
  const LyricLineTile({
    super.key,
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: isActive
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          // Las pausas instrumentales se ven como "♪".
          child: Text(text.isEmpty ? '♪' : text),
        ),
      ),
    );
  }
}
