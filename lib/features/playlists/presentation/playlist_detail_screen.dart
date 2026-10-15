import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/playlist.dart';
import '../../../core/models/song.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_tile.dart';
import '../data/playlist_cover_service.dart';
import 'playlists_providers.dart';
import 'widgets/playlist_cover.dart';

void openPlaylist(BuildContext context, String id) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => PlaylistDetailScreen(id: id)));

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playlistProvider(id));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (playlist) => playlist == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.delete_outline_rounded,
                title: 'Esta playlist ya no existe',
              ),
            )
          : _PlaylistView(playlist: playlist),
    );
  }
}

/// Fila de menú con icono; [color] tiñe icono y texto (p. ej. borrar).
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: color)),
    ],
  );
}

class _PlaylistView extends ConsumerStatefulWidget {
  const _PlaylistView({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends ConsumerState<_PlaylistView> {
  /// Copia local para aplicar al instante quitar/reordenar; la BD confirma
  /// después y [didUpdateWidget] la sustituye por la versión guardada.
  late List<Song> _songs = widget.playlist.songs;

  @override
  void didUpdateWidget(_PlaylistView old) {
    super.didUpdateWidget(old);
    if (!identical(old.playlist, widget.playlist)) {
      _songs = widget.playlist.songs;
    }
  }

  void _removeAt(int i) {
    setState(() => _songs = [..._songs]..removeAt(i));
    ref.read(playlistDaoProvider).removeAt(widget.playlist.id, i);
  }

  /// Deshacer un quitar: la BD añade al final y se reubica en [i].
  Future<void> _restore(int i, Song song) async {
    final last = _songs.length;
    final at = i > last ? last : i;
    setState(() {
      final list = [..._songs];
      list.insert(at, song);
      _songs = list;
    });
    final dao = ref.read(playlistDaoProvider);
    final added = await dao.addSong(widget.playlist.id, song);
    if (added && at != last) {
      await dao.move(widget.playlist.id, last, at);
    }
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      final list = [..._songs];
      list.insert(newIndex, list.removeAt(oldIndex));
      _songs = list;
    });
    ref.read(playlistDaoProvider).move(widget.playlist.id, oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final dao = ref.read(playlistDaoProvider);
    // Solo se lee al usarlo: no hace falta para pintar la pantalla.
    PlaylistCoverService covers() => ref.read(playlistCoverServiceProvider);
    final actions = ref.read(songActionsProvider);
    final theme = Theme.of(context);
    final songs = _songs;

    Future<void> rename() async {
      final name = await showTextInputDialog(
        context,
        title: 'Renombrar playlist',
        initialValue: playlist.name,
      );
      if (name != null) await dao.rename(playlist.id, name);
    }

    Future<void> delete() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Borrar playlist',
        message:
            '¿Borrar "${playlist.name}"? Las canciones descargadas '
            'se mantienen en Descargas.',
      );
      if (!ok) return;
      await covers().deletePlaylist(playlist.id);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> changeCover() async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image != null) await covers().setFromFile(playlist.id, image.path);
    }

    Future<void> removeCover() => covers().clear(playlist.id);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          PlaylistCover(playlist, size: 180, radius: 12),
          const SizedBox(height: 16),
          Text(
            playlist.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${songCount(songs.length)} · '
            '${formatDuration(playlist.totalDuration)}'
            '${playlist.downloadedCount > 0 ? ' · ${downloadedLabel(playlist.downloadedCount)}' : ''}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => actions.playQueue(songs, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => actions.playShuffled(songs),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatorio'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: songs.isEmpty || playlist.isFullyDownloaded
                      ? null
                      : () async {
                          await actions.downloadAll(songs);
                          if (context.mounted) {
                            showSnack(context, 'Descargando la playlist…');
                          }
                        },
                  icon: Icon(
                    playlist.isFullyDownloaded
                        ? Icons.offline_pin_rounded
                        : Icons.download_for_offline_outlined,
                  ),
                  label: Text(
                    playlist.isFullyDownloaded ? 'Descargada' : 'Descargar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<VoidCallback>(
            onSelected: (f) => f(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: rename,
                child: _MenuRow(Icons.edit_outlined, 'Renombrar'),
              ),
              PopupMenuItem(
                value: changeCover,
                child: _MenuRow(Icons.image_outlined, 'Cambiar portada'),
              ),
              if (playlist.coverUrl != null)
                PopupMenuItem(
                  value: removeCover,
                  child: _MenuRow(
                    Icons.hide_image_outlined,
                    'Quitar portada',
                  ),
                ),
              PopupMenuItem(
                value: delete,
                child: _MenuRow(
                  Icons.delete_outline_rounded,
                  'Borrar playlist',
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
      body: songs.isEmpty
          ? ListView(
              children: [
                header,
                const EmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: 'Playlist vacía',
                  message: 'Añade canciones desde el buscador con el menú ⋮.',
                ),
              ],
            )
          : ReorderableListView.builder(
              header: header,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: songs.length,
              onReorderItem: _move,
              itemBuilder: (context, i) {
                final song = songs[i];
                // Un solo Dismissible para los dos sentidos: derecha encola
                // (y la fila vuelve), izquierda quita de la playlist.
                return Dismissible(
                  key: ValueKey(song.id),
                  background: const QueueSwipeBackground(),
                  confirmDismiss: (direction) async =>
                      direction == DismissDirection.endToStart ||
                      await queueOnSwipe(context, actions, song),
                  secondaryBackground: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quitar',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.playlist_remove_rounded,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    _removeAt(i);
                    showSnack(
                      context,
                      'Quitada de "${playlist.name}"',
                      action: SnackBarAction(
                        label: 'Deshacer',
                        onPressed: () => _restore(i, song),
                      ),
                    );
                  },
                  child: SongTile(
                    song: song,
                    swipeToQueue: false,
                    onTap: () => actions.playQueue(songs, i),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator_rounded),
                          const SizedBox(width: 8),
                          ArtworkImage(url: song.artworkUrl, seed: song.title),
                        ],
                      ),
                    ),
                    extraActions: [
                      SongMenuAction(
                        'Quitar de la playlist',
                        Icons.playlist_remove_rounded,
                        () => _removeAt(i),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
