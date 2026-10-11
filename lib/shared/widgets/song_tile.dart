import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_providers.dart';
import '../../core/models/song.dart';
import '../../core/utils/formatters.dart';
import '../../features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../song_actions.dart';
import 'artwork_image.dart';
import 'dialogs.dart';
import 'download_button.dart';

/// Acción extra del menú de una fila (p. ej. "Quitar de la playlist").
class SongMenuAction {
  const SongMenuAction(this.label, this.icon, this.onSelected);

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Fila de canción usada en búsqueda, playlists y descargas.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.extraActions = const [],
    this.leading,
    this.showDownloadButton = true,
  });

  final Song song;
  final VoidCallback onTap;
  final List<SongMenuAction> extraActions;

  /// Sustituye la carátula (p. ej. por un asa de arrastre).
  final Widget? leading;
  final bool showDownloadButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      playerSnapshotProvider.select((s) => s.value?.currentSong == song),
    );
    final theme = Theme.of(context);
    final actions = ref.read(songActionsProvider);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: leading ?? ArtworkImage(url: song.artworkUrl, seed: song.title),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      subtitle: Text(
        '${song.artist} · ${formatDuration(song.duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDownloadButton) DownloadButton(song: song),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => action(),
            // `_`: los callbacks deben usar el context de la fila, no el del
            // menú, que ya se ha cerrado cuando se ejecutan.
            itemBuilder: (_) => [
              _item(
                Icons.playlist_play_rounded,
                'Reproducir a continuación',
                () async {
                  await actions.playNext(song);
                  if (context.mounted) {
                    showSnack(context, 'Sonará a continuación');
                  }
                },
              ),
              _item(Icons.queue_music_rounded, 'Añadir a la cola', () async {
                await actions.addToQueue(song);
                if (context.mounted) {
                  showSnack(context, 'Añadida a la cola');
                }
              }),
              _item(
                Icons.playlist_add_rounded,
                'Añadir a una playlist',
                () => showAddToPlaylistSheet(context, song),
              ),
              for (final extra in extraActions)
                _item(extra.icon, extra.label, extra.onSelected),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String label,
    VoidCallback onSelected,
  ) => PopupMenuItem(
    value: onSelected,
    child: Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    ),
  );
}
