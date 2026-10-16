import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../data/download_manager.dart';

/// Canciones descargadas, las más recientes primero.
final downloadedSongsProvider =
    AsyncNotifierProvider<DownloadsNotifier, List<Song>>(
      DownloadsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de canciones descargadas y de su borrado.
///
/// Se recarga sola cuando el [DownloadManager] avisa de que un archivo
/// apareció o desapareció (`downloadsChanged`): una descarga que termina en
/// segundo plano, un borrado desde cualquier pantalla o un archivo perdido.
/// El progreso de las descargas no la recarga.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class DownloadsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final repository = ref.watch(songRepositoryProvider);
    final changes = ref
        .watch(downloadManagerProvider)
        .downloadsChanged
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);
    return switch (await repository.getDownloaded()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  DownloadManager get _manager => ref.read(downloadManagerProvider);

  /// Borra el archivo de [song]; sigue en sus playlists para streaming.
  Future<Result<Song>> delete(Song song) async {
    final result = await _manager.delete(song);
    _refresh();
    return result;
  }

  /// Borra todas las descargas. Se detiene en el primer fallo y lo devuelve.
  Future<Result<Unit>> deleteAll() async {
    final result = await _manager.deleteAll();
    _refresh();
    return result;
  }

  /// Se recarga también tras un `Err`: el borrado pudo quedarse a medias.
  void _refresh() {
    if (ref.mounted) ref.invalidateSelf();
  }
}
