import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/domain/entities/playlist.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/song_tile.dart';
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
      // Al recargar (p. ej. termina una descarga) se sigue viendo la lista.
      skipLoadingOnReload: true,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: e is NotFoundFailure
            ? const EmptyState(
                icon: Icons.delete_outline_rounded,
                title: 'Esta playlist ya no existe',
              )
            : ErrorView(
                error: e,
                title: 'No se pudo abrir la playlist',
                onRetry: () => ref.invalidate(playlistProvider(id)),
              ),
      ),
      data: (playlist) => _PlaylistView(playlist: playlist),
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

/// Pinta la playlist tal y como la expone [playlistProvider]. Quitar,
/// deshacer y el resto de acciones son métodos de los notifiers: el estado
/// optimista y su vuelta atrás viven allí, no en el widget.
class _PlaylistView extends ConsumerStatefulWidget {
  const _PlaylistView({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends ConsumerState<_PlaylistView> {
  /// Solo visual: entra en la clave de las filas y cambia con cada
  /// deslizamiento. Si la BD falla y el notifier devuelve la canción antes
  /// de que se pinte el frame sin ella, la fila vuelve como un Dismissible
  /// nuevo (el deslizado no puede seguir en el árbol).
  int _dismissals = 0;

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final detail = ref.read(playlistProvider(playlist.id).notifier);
    final playlists = ref.read(playlistsProvider.notifier);
    final actions = ref.read(songActionsProvider);
    final theme = Theme.of(context);
    final songs = playlist.songs;

    /// Avisa si [result] es un `Err` y la pantalla sigue abierta.
    void reportErr(Result<Object?> result, String message) {
      if (result.isErr && context.mounted) showSnack(context, message);
    }

    Future<void> removeAt(int i) async =>
        reportErr(await detail.removeSongAt(i), 'No se pudo quitar la canción');

    /// Deshacer un quitar: la vuelve a poner en la posición [i].
    Future<void> restore(int i, Song song) async {
      // Con la pantalla cerrada ya no hay detalle que restaurar.
      if (!context.mounted) return;
      reportErr(
        await detail.addSong(song, at: i),
        'No se pudo volver a añadir la canción',
      );
    }

    Future<void> rename() async {
      final name = await showTextInputDialog(
        context,
        title: 'Renombrar playlist',
        initialValue: playlist.name,
      );
      if (name == null) return;
      reportErr(await detail.rename(name), 'No se pudo renombrar la playlist');
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
      final deleted = await playlists.delete(playlist.id);
      if (!context.mounted) return;
      if (deleted.isOk) {
        Navigator.pop(context);
      } else {
        showSnack(context, 'No se pudo borrar la playlist');
      }
    }

    Future<void> changeCover() async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image == null) return;
      reportErr(
        await playlists.setCoverFromFile(playlist.id, image.path),
        'No se pudo cambiar la portada',
      );
    }

    Future<void> removeCover() async => reportErr(
      await playlists.clearCover(playlist.id),
      'No se pudo quitar la portada',
    );

    final meta = [
      if (playlist.isFullyDownloaded) 'Descargada',
      if (!playlist.isFullyDownloaded && playlist.downloadedCount > 0)
        downloadedLabel(playlist.downloadedCount),
      songCount(songs.length),
      formatDuration(playlist.totalDuration),
    ];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: PlaylistCover(playlist, size: 250, radius: 6)),
          const SizedBox(height: 24),
          Text(
            playlist.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
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
                  size: 28,
                  color: playlist.isFullyDownloaded
                      ? theme.colorScheme.primary
                      : null,
                ),
              ),
              PopupMenuButton<VoidCallback>(
                tooltip: 'Más opciones',
                icon: const Icon(Icons.more_horiz_rounded, size: 28),
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
              const Spacer(),
              IconButton(
                tooltip: 'Aleatorio',
                onPressed: songs.isEmpty
                    ? null
                    : () => actions.playShuffled(songs),
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Reproducir',
                iconSize: 32,
                onPressed: songs.isEmpty
                    ? null
                    : () => actions.playQueue(songs, 0),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.2),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: songs.isEmpty
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
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: songs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return header;
                  final i = index - 1;
                  final song = songs[i];
                  // Un solo Dismissible para los dos sentidos: derecha encola
                  // (y la fila vuelve), izquierda quita de la playlist.
                  return Dismissible(
                    key: ValueKey((song.id, _dismissals)),
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
                      // El estado optimista quita la fila en este mismo
                      // frame; si la BD falla, vuelve y se avisa.
                      setState(() => _dismissals++);
                      removeAt(i);
                      showSnack(
                        context,
                        'Quitada de "${playlist.name}"',
                        action: SnackBarAction(
                          label: 'Deshacer',
                          onPressed: () => restore(i, song),
                        ),
                      );
                    },
                    child: SongTile(
                      song: song,
                      swipeToQueue: false,
                      onTap: () => actions.playQueue(songs, i),
                      leading: ArtworkImage(
                        url: song.artworkUrl,
                        seed: song.title,
                        size: 48,
                        radius: 4,
                      ),
                      extraActions: [
                        SongMenuAction(
                          'Quitar de la playlist',
                          Icons.playlist_remove_rounded,
                          () => removeAt(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
