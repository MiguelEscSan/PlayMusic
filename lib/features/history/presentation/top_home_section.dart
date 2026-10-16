import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../home/home_sections.dart';
import 'history_providers.dart';

/// Sección de Inicio con la portada de lo más escuchado del último mes.
final topHomeSection = HomeSection(
  id: 'top',
  order: 5,
  builder: (_) => const TopHomeSection(),
  hasContent: Provider(
    (ref) => ref.watch(topSongsProvider).value?.isNotEmpty ?? false,
  ),
);

/// Portada "Más escuchadas": mosaico 2×2 con las carátulas de las cuatro
/// canciones más escuchadas y botón para reproducir el top entero. Sin
/// historial no ocupa espacio.
class TopHomeSection extends ConsumerWidget {
  const TopHomeSection({super.key});

  static const _mosaic = 140.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(topSongsProvider).value ?? const <Song>[];
    if (songs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final covers = songs.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: _mosaic,
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 4; i++)
                      ArtworkImage(
                        url: i < covers.length ? covers[i].artworkUrl : null,
                        seed: i < covers.length ? covers[i].title : 'top$i',
                        size: (_mosaic - 4) / 2,
                        radius: 0,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MÁS ESCUCHADAS',
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text('Tu top del mes', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${songCount(songs.length)} · últimos 30 días',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(songActionsProvider).playQueue(songs, 0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Reproducir'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
