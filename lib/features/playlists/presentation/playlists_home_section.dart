import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../home/home_sections.dart';
import 'playlist_detail_screen.dart';
import 'playlists_providers.dart';
import 'widgets/playlist_cover.dart';

/// Registro de la sección para [homeSectionsProvider].
final playlistsHomeSection = HomeSection(
  id: 'playlists',
  order: 15,
  builder: (_) => const PlaylistsHomeSection(),
  hasContent: Provider(
    (ref) => ref.watch(playlistsProvider).value?.isNotEmpty ?? false,
  ),
);

/// Dos playlists más recientes en cuadrícula, para abrirlas desde Inicio.
/// No ocupa sitio si no hay ninguna.
class PlaylistsHomeSection extends ConsumerWidget {
  const PlaylistsHomeSection({super.key});

  static const _count = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    if (playlists.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = playlists.take(_count).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < _count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: i < shown.length
                  ? Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => openPlaylist(context, shown[i].id),
                        child: Row(
                          children: [
                            PlaylistCover(shown[i], size: 64, radius: 0),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      shown[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      songCount(shown[i].length),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
