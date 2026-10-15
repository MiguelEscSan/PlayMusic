import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_providers.dart';
import '../../core/models/song.dart';
import '../../core/utils/formatters.dart';
import '../../features/favorites/presentation/favorites_providers.dart';
import '../../features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../export/song_exporter.dart';
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

/// Fondo que asoma al deslizar una fila a la derecha para encolarla.
class QueueSwipeBackground extends StatelessWidget {
  const QueueSwipeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      child: Icon(Icons.queue_music_rounded, color: scheme.onPrimaryContainer),
    );
  }
}

/// `confirmDismiss` de "deslizar para encolar": añade [song] a la cola, avisa
/// y devuelve `false` para que la fila vuelva a su sitio.
Future<bool> queueOnSwipe(
  BuildContext context,
  SongActions actions,
  Song song,
) async {
  await actions.addToQueue(song);
  if (context.mounted) showSnack(context, 'Añadida a la cola');
  return false;
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
    this.swipeToQueue = true,
  });

  final Song song;
  final VoidCallback onTap;
  final List<SongMenuAction> extraActions;

  /// Sustituye la carátula (p. ej. por un asa de arrastre).
  final Widget? leading;
  final bool showDownloadButton;

  /// Deslizar a la derecha añade a la cola. Desactívalo si la fila ya va
  /// dentro de otro [Dismissible]: dos gestos horizontales anidados se pelean
  /// y el interior se tragaría el del padre. Ese padre puede reutilizar
  /// [QueueSwipeBackground] y [queueOnSwipe].
  final bool swipeToQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      playerSnapshotProvider.select((s) => s.value?.currentSong == song),
    );
    final isLiked = ref.watch(isLikedProvider(song));
    final theme = Theme.of(context);
    final actions = ref.read(songActionsProvider);

    final tile = ListTile(
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
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                isLiked ? 'Quitar de Me gusta' : 'Me gusta',
                () => actions.toggleLike(song),
              ),
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
              if (song.isDownloaded)
                _item(
                  Icons.save_alt_rounded,
                  'Exportar a Música',
                  () => _export(context, actions),
                ),
              for (final extra in extraActions)
                _item(extra.icon, extra.label, extra.onSelected),
            ],
          ),
        ],
      ),
    );

    if (!swipeToQueue) return tile;
    return Dismissible(
      key: ObjectKey(song),
      direction: DismissDirection.startToEnd,
      background: const QueueSwipeBackground(),
      // Nunca se descarta: la fila vuelve a su sitio tras encolar.
      confirmDismiss: (_) => queueOnSwipe(context, actions, song),
      child: tile,
    );
  }

  Future<void> _export(BuildContext context, SongActions actions) async {
    String message;
    try {
      await actions.exportToMusic(song);
      message = 'Guardada en Música/Koda';
    } on SongExportException catch (e) {
      message = e.message;
    }
    if (context.mounted) showSnack(context, message);
  }

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String label,
    VoidCallback onSelected,
  ) => PopupMenuItem(
    value: onSelected,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
