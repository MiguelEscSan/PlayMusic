import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playlist.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import 'playlist_detail_screen.dart';
import 'playlists_providers.dart';
import 'widgets/playlist_cover.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showTextInputDialog(
      context,
      title: 'Nueva playlist',
      hint: 'Nombre',
      confirmLabel: 'Crear',
    );
    if (name == null) return;
    final playlist = await ref.read(playlistDaoProvider).create(name);
    if (context.mounted) openPlaylist(context, playlist.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
      ),
      body: playlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'Aún no tienes playlists',
                message:
                    'Crea una o añade canciones desde el buscador '
                    'con el menú ⋮.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive: lista en móvil, rejilla en tablet/horizontal.
                  if (constraints.maxWidth < 600) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _PlaylistRow(list[i]),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _PlaylistCard(list[i]),
                  );
                },
              ),
      ),
    );
  }
}

String _subtitle(Playlist p) {
  final parts = [songCount(p.length)];
  if (p.downloadedCount > 0) {
    parts.add(
      p.isFullyDownloaded ? 'descargada' : downloadedLabel(p.downloadedCount),
    );
  }
  return parts.join(' · ');
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow(this.playlist);

  final Playlist playlist;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => openPlaylist(context, playlist.id),
    leading: PlaylistCover(playlist, size: 56),
    title: Text(playlist.name),
    subtitle: Text(_subtitle(playlist)),
    trailing: playlist.isFullyDownloaded
        ? Icon(
            Icons.offline_pin_rounded,
            color: Theme.of(context).colorScheme.primary,
          )
        : null,
  );
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard(this.playlist);

  final Playlist playlist;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => openPlaylist(context, playlist.id),
    child: LayoutBuilder(
      builder: (context, c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaylistCover(playlist, size: c.maxWidth, radius: 12),
          const SizedBox(height: 8),
          Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            _subtitle(playlist),
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
