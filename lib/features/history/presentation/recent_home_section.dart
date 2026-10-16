import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../home/home_sections.dart';
import 'history_providers.dart';

/// Sección de Inicio con lo último que sonó.
final recentHomeSection = HomeSection(
  id: 'recent',
  order: 20,
  builder: (_) => const RecentHomeSection(),
  hasContent: Provider(
    (ref) => ref.watch(recentSongsProvider).value?.isNotEmpty ?? false,
  ),
);

/// "Escuchado recientemente": lista vertical de las últimas canciones.
/// Tocar una reproduce la lista desde esa canción. Sin historial no ocupa
/// espacio.
class RecentHomeSection extends ConsumerWidget {
  const RecentHomeSection({super.key});

  static const _maxSongs = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(recentSongsProvider).value ?? const <Song>[];
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
