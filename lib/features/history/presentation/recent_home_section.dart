import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/song.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../home/home_sections.dart';
import 'history_providers.dart';

/// Sección de Inicio con lo último que sonó.
final recentHomeSection = HomeSection(
  id: 'recent',
  order: 20,
  builder: (_) => const RecentHomeSection(),
);

/// "Escuchado recientemente": fila horizontal de carátulas. Tocar una
/// reproduce la lista entera desde esa canción. Sin historial no ocupa
/// espacio.
class RecentHomeSection extends ConsumerWidget {
  const RecentHomeSection({super.key});

  static const _cover = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(recentSongsProvider).value ?? const <Song>[];
    if (songs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Escuchado recientemente',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => ref.read(historyDaoProvider).clear(),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _cover + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecentCard(
              song: songs[i],
              size: _cover,
              onTap: () => ref.read(songActionsProvider).playQueue(songs, i),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.song,
    required this.size,
    required this.onTap,
  });

  final Song song;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkImage(
              url: song.artworkUrl,
              seed: song.title,
              size: size,
              radius: 8,
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
