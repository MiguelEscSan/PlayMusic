import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/song_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/song_tile.dart';
import 'favorites_providers.dart';

void openLikedSongs(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const LikedSongsScreen()));
}

/// Lista completa de favoritas. Tocar una reproduce toda la lista desde ahí.
class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(songActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Canciones que te gustan')),
      body: ref
          .watch(likedSongsProvider)
          .when(
            // Al quitar un "me gusta" se sigue viendo la lista mientras recarga.
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              error: e,
              title: 'No se pudieron cargar tus favoritas',
              onRetry: () => ref.invalidate(likedSongsProvider),
            ),
            data: (songs) => songs.isEmpty
                ? const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Aún no te gusta ninguna canción',
                    message:
                        'Usa "Me gusta" en el menú de una canción o el corazón '
                        'del reproductor para guardarla aquí.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: songs[i],
                      onTap: () => actions.playQueue(songs, i),
                    ),
                  ),
          ),
    );
  }
}
