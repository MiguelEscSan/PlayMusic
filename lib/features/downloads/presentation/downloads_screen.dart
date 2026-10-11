import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/artwork_image.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_tile.dart';
import '../domain/download_task.dart';
import 'downloads_providers.dart';

/// Gestión del almacenamiento: descargas en curso, espacio ocupado y
/// borrado de archivos locales.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadedSongsProvider).value ?? const [];
    final bytes = ref.watch(downloadsSizeProvider).value ?? 0;
    final tasks = ref.watch(downloadTasksProvider).value ?? const {};
    final inProgress = tasks.values
        .where((t) => t.isActive || t.status == DownloadStatus.failed)
        .toList();
    final actions = ref.read(songActionsProvider);

    Future<void> deleteAll() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Borrar todas las descargas',
        message:
            'Se liberarán ${formatBytes(bytes)}. Las canciones '
            'seguirán en tus playlists para escucharlas en streaming.',
        confirmLabel: 'Borrar todo',
      );
      if (ok) await ref.read(downloadManagerProvider).deleteAll();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          if (downloaded.isNotEmpty)
            IconButton(
              tooltip: 'Borrar todas',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: deleteAll,
            ),
        ],
      ),
      body: downloaded.isEmpty && inProgress.isEmpty
          ? const EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: 'Sin descargas',
              message:
                  'Toca el icono de descarga en cualquier canción para '
                  'escucharla sin conexión.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ListTile(
                    leading: const Icon(Icons.sd_storage_rounded),
                    title: Text(formatBytes(bytes)),
                    subtitle: Text(
                      '${songCount(downloaded.length)} disponibles sin conexión',
                    ),
                  ),
                ),
                if (inProgress.isNotEmpty) ...[
                  _SectionTitle('En curso (${inProgress.length})'),
                  for (final task in inProgress) _TaskTile(task),
                ],
                if (downloaded.isNotEmpty) ...[
                  const _SectionTitle('Descargadas'),
                  for (var i = 0; i < downloaded.length; i++)
                    SongTile(
                      song: downloaded[i],
                      onTap: () => actions.playQueue(downloaded, i),
                    ),
                ],
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile(this.task);

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(songActionsProvider);
    final failed = task.status == DownloadStatus.failed;
    final progress = task.progress;
    final scheme = Theme.of(context).colorScheme;

    final detail = switch (task.status) {
      DownloadStatus.queued => 'En cola',
      DownloadStatus.failed => task.error ?? 'Error',
      _ when progress != null =>
        '${(progress * 100).round()} % · ${formatBytes(task.receivedBytes)}'
            ' de ${formatBytes(task.totalBytes!)}',
      _ => formatBytes(task.receivedBytes),
    };

    return ListTile(
      leading: ArtworkImage(url: task.song.artworkUrl, seed: task.song.title),
      title: Text(
        task.song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: failed ? 0 : progress,
            color: failed ? scheme.error : null,
          ),
          const SizedBox(height: 4),
          Text(detail, style: failed ? TextStyle(color: scheme.error) : null),
        ],
      ),
      trailing: failed
          ? IconButton(
              tooltip: 'Reintentar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => actions.download(task.song),
            )
          : IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => actions.cancelDownload(task.song),
            ),
    );
  }
}
