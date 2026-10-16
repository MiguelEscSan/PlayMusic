import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../home/home_sections.dart';
import 'favorites_providers.dart';
import 'liked_songs_screen.dart';

/// Registro de la sección para [homeSectionsProvider].
final likedHomeSection = HomeSection(
  id: 'favorites',
  order: 10,
  builder: (_) => const LikedHomeSection(),
  // Un fallo al cargar también se enseña (con su botón de reintentar).
  hasContent: Provider((ref) {
    final liked = ref.watch(likedSongsProvider);
    return liked.hasError || (liked.value?.isNotEmpty ?? false);
  }),
);

/// Bloque "Te gusta" de Inicio: las últimas favoritas y acceso a la lista
/// completa. No ocupa sitio si aún no hay ninguna.
class LikedHomeSection extends ConsumerWidget {
  const LikedHomeSection({super.key});

  static const _maxSongs = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider);
    if (liked.hasError) {
      return ErrorView(
        error: liked.error!,
        title: 'No se pudieron cargar tus favoritas',
        onRetry: () => ref.invalidate(likedSongsProvider),
      );
    }
    final songs = liked.value ?? const [];
    if (songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
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
            onTap: () => ref.read(playQueueUseCaseProvider)(songs, i),
          ),
      ],
    );
  }
}
