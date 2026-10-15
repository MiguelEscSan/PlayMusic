import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/song_actions.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../home/home_sections.dart';
import 'favorites_providers.dart';
import 'liked_songs_screen.dart';

/// Registro de la sección para [homeSectionsProvider].
final likedHomeSection = HomeSection(
  id: 'favorites',
  order: 10,
  builder: (_) => const LikedHomeSection(),
  hasContent: Provider(
    (ref) => ref.watch(likedSongsProvider).value?.isNotEmpty ?? false,
  ),
);

/// Bloque "Te gusta" de Inicio: las últimas favoritas y acceso a la lista
/// completa. No ocupa sitio si aún no hay ninguna.
class LikedHomeSection extends ConsumerWidget {
  const LikedHomeSection({super.key});

  static const _maxSongs = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(likedSongsProvider).value ?? const [];
    if (songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final actions = ref.read(songActionsProvider);
    final shown = songs.take(_maxSongs).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Te gusta', style: theme.textTheme.titleLarge),
                    Text(
                      songs.length == 1
                          ? '1 canción'
                          : '${songs.length} canciones',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => openLikedSongs(context),
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        for (var i = 0; i < shown.length; i++)
          SongTile(
            song: shown[i],
            showDownloadButton: false,
            onTap: () => actions.playQueue(songs, i),
          ),
      ],
    );
  }
}
