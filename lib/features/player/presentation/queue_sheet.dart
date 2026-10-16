import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/formatters.dart';
import '../../../di/providers.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/dialogs.dart';
import 'player_providers.dart';

Future<void> showQueueSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _QueueSheet(),
);

/// Cola de reproducción: toca para saltar, arrastra para reordenar,
/// desliza para quitar.
class _QueueSheet extends ConsumerStatefulWidget {
  const _QueueSheet();

  @override
  ConsumerState<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<_QueueSheet> {
  /// Copia local para que quitar/reordenar se vea al instante, sin esperar
  /// al siguiente estado del reproductor.
  List<Song>? _local;
  List<Song>? _lastRemote;

  /// Lanza un cambio de la cola. Si falla, vuelve a mostrar la cola que
  /// tiene el reproductor (deshace el cambio optimista) y avisa.
  Future<void> _mutate(
    Future<Result<Unit>> Function() action,
    String errorMessage,
  ) async {
    final result = await action();
    if (result.isOk || !mounted) return;
    setState(() => _local = _lastRemote);
    showSnack(context, errorMessage);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(playerSnapshotProvider).value;
    final remote = snapshot?.queue ?? const <Song>[];
    if (!identical(remote, _lastRemote)) {
      _lastRemote = remote;
      _local = remote;
    }
    final queue = _local!;
    final currentSong = snapshot?.currentSong;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('Cola', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text(songCount(queue.length)),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: queue.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final list = [...queue];
                  list.insert(newIndex, list.removeAt(oldIndex));
                  _local = list;
                });
                _mutate(
                  () =>
                      ref.read(moveInQueueUseCaseProvider)(oldIndex, newIndex),
                  'No se pudo reordenar la cola',
                );
              },
              itemBuilder: (context, i) {
                final song = queue[i];
                final isCurrent = identical(song, currentSong);
                return Dismissible(
                  key: ObjectKey(song),
                  direction: isCurrent
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: scheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  onDismissed: (_) {
                    setState(() => _local = [...queue]..removeAt(i));
                    _mutate(
                      () => ref.read(removeFromQueueUseCaseProvider)(i),
                      'No se pudo quitar la canción de la cola',
                    );
                  },
                  child: ListTile(
                    onTap: () => _mutate(
                      () => ref.read(skipToQueueIndexUseCaseProvider)(i),
                      'No se pudo reproducir esa canción',
                    ),
                    leading: ArtworkImage(
                      url: song.artworkUrl,
                      seed: song.title,
                      size: 40,
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isCurrent
                          ? TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                    subtitle: Text(song.artist, maxLines: 1),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
