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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: PlaylistCover(playlist, size: 180, radius: 12)),
          const SizedBox(height: 16),
          Text(playlist.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${songCount(songs.length)} · '
            '${formatDuration(playlist.totalDuration)}'
            '${playlist.downloadedCount > 0 ? ' · ${downloadedLabel(playlist.downloadedCount)}' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: songs.isEmpty
                    ? null
                    : () => actions.playQueue(songs, 0),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reproducir'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: songs.isEmpty
                    ? null
                    : () => actions.playShuffled(songs),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Aleatorio'),
              ),
              const Spacer(),
              IconButton(
                tooltip: playlist.isFullyDownloaded
                    ? 'Toda la playlist está descargada'
                    : 'Descargar toda la playlist',
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
                  color: playlist.isFullyDownloaded
                      ? theme.colorScheme.primary
                      : null,
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
              PopupMenuItem(value: rename, child: const Text('Renombrar')),
              PopupMenuItem(
                value: changeCover,
                child: const Text('Cambiar portada'),
              ),
              if (playlist.coverUrl != null)
                PopupMenuItem(
                  value: removeCover,
                  child: const Text('Quitar portada'),
                ),
              PopupMenuItem(
                value: delete,
                child: const Text('Borrar playlist'),
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
                return Dismissible(
                  key: ValueKey(song.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.playlist_remove_rounded),
                  ),
                  onDismissed: (_) {
                    _removeAt(i);
                    showSnack(context, 'Quitada de "${playlist.name}"');
                  },
                  child: SongTile(
                    song: song,
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
