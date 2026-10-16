import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../../downloads/data/download_manager.dart';

/// Canciones con "me gusta", la última marcada primero.
final likedSongsProvider =
    AsyncNotifierProvider<LikedSongsNotifier, List<Song>>(
      LikedSongsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de favoritas.
///
/// El único que escribe "me gusta" es `SongActions.toggleLike`, que la
/// invalida al cambiar una canción. Además se recarga cuando el
/// [DownloadManager] avisa de que un archivo apareció o desapareció
/// (`downloadsChanged`), para que las favoritas lleven su `localPath` actual.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class LikedSongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final repository = ref.watch(songRepositoryProvider);
    final changes = ref
        .watch(downloadManagerProvider)
        .downloadsChanged
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);
    return switch (await repository.getLiked()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
