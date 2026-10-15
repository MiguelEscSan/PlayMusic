import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/song.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../playlists_providers.dart';
import 'playlist_cover.dart';

Future<void> showAddToPlaylistSheet(BuildContext context, Song song) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AddToPlaylistSheet(song: song, parent: context),
    );

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.song, required this.parent});

  final Song song;

  /// Contexto de la pantalla, para mostrar el aviso tras cerrar la hoja.
  final BuildContext parent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final dao = ref.read(playlistDaoProvider);

    Future<void> addTo(String id, String name) async {
      final added = await dao.addSong(id, song);
      if (context.mounted) Navigator.pop(context);
      if (parent.mounted) {
        showSnack(parent, added ? 'Añadida a "$name"' : 'Ya estaba en "$name"');
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Añadir a una playlist',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
            title: const Text('Nueva playlist'),
            onTap: () async {
              final name = await showTextInputDialog(
                context,
                title: 'Nueva playlist',
                hint: 'Nombre',
                confirmLabel: 'Crear',
              );
              if (name == null) return;
              final created = await dao.create(name);
              await addTo(created.id, created.name);
            },
          ),
          for (final p in playlists)
            ListTile(
              leading: PlaylistCover(p, size: 40),
              title: Text(p.name),
              subtitle: Text(songCount(p.length)),
              onTap: () => addTo(p.id, p.name),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
