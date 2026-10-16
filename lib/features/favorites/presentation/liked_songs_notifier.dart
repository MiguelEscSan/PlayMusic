import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';

/// Canciones con "me gusta", la última marcada primero.
final likedSongsProvider =
    AsyncNotifierProvider<LikedSongsNotifier, List<Song>>(
      LikedSongsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de favoritas.
///
/// El único que escribe "me gusta" es `SongActions.toggleLike` (con
/// `ToggleLikeUseCase`), que la invalida al cambiar una canción. Además se
/// recarga cuando un archivo descargado aparece o desaparece
/// (`WatchDownloadsChangedUseCase`), para que las favoritas lleven su
/// `localPath` actual.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class LikedSongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final getLiked = ref.watch(getLikedSongsUseCaseProvider);
    final changes = ref
        .watch(watchDownloadsChangedUseCaseProvider)()
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);
    return switch (await getLiked()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
