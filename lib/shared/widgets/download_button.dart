import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/entities/song.dart';
import '../../di/providers.dart';
import '../../core/domain/song_key.dart';
import '../../features/downloads/domain/download_task.dart';
import '../../features/downloads/presentation/downloads_providers.dart';
import 'dialogs.dart';

/// Botón de descarga con todos sus estados:
/// descargar → en cola → progreso circular (toca para cancelar) →
/// descargada (toca para borrar) · error (toca para reintentar).
class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key, required this.song, this.size = 24});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(downloadTaskProvider(song));
    final downloaded =
        song.isDownloaded ||
        ref.watch(downloadedKeysProvider).contains(songKey(song));
    final scheme = Theme.of(context).colorScheme;

    Widget button({
      required Widget icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) => IconButton(
      tooltip: tooltip,
      iconSize: size,
      onPressed: onPressed,
      icon: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
    );

    if (task?.status == DownloadStatus.downloading) {
      final progress = task!.progress;
      return button(
        tooltip: progress == null
            ? 'Descargando…'
            : 'Descargando ${(progress * 100).round()} % · toca para cancelar',
        onPressed: () => ref.read(cancelDownloadUseCaseProvider)(song),
        icon: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            Icon(Icons.stop_rounded, size: size * 0.5),
          ],
        ),
      );
    }

    if (task?.status == DownloadStatus.queued) {
      return button(
        tooltip: 'En cola · toca para cancelar',
        onPressed: () => ref.read(cancelDownloadUseCaseProvider)(song),
        icon: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (downloaded && task?.status != DownloadStatus.cancelled) {
      return button(
        tooltip: 'Descargada · toca para borrar',
        icon: Icon(Icons.download_done_rounded, color: scheme.primary),
        onPressed: () async {
          final ok = await showConfirmDialog(
            context,
            title: 'Borrar descarga',
            message:
                '"${song.title}" dejará de estar disponible sin conexión. '
                'Seguirá en tus playlists.',
          );
          if (!ok) return;
          final result = await ref
              .read(downloadedSongsProvider.notifier)
              .delete(song);
          if (result.isErr && context.mounted) {
            showSnack(context, 'No se pudo borrar la descarga');
          }
        },
      );
    }

    if (task?.status == DownloadStatus.failed) {
      return button(
        tooltip: '${task!.error ?? 'Error'} · toca para reintentar',
        icon: Icon(Icons.refresh_rounded, color: scheme.error),
        onPressed: () => ref.read(downloadSongUseCaseProvider)(song),
      );
    }

    return button(
      tooltip: 'Descargar',
      icon: const Icon(Icons.download_rounded),
      onPressed: () => ref.read(downloadSongUseCaseProvider)(song),
    );
  }
}
