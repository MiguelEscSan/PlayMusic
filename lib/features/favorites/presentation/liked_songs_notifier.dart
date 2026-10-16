import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../../playlists/presentation/playlists_providers.dart';
import '../domain/i_liked_playlist_sync.dart';

/// Canciones con "me gusta", la última marcada primero.
final likedSongsProvider =
    AsyncNotifierProvider<LikedSongsNotifier, List<Song>>(
      LikedSongsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de favoritas y del único punto que escribe "me gusta"
/// ([toggle], con `ToggleLikeUseCase`).
///
/// Además se recarga cuando un archivo descargado aparece o desaparece
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

  /// Alterna "me gusta" con `ToggleLikeUseCase` (guarda la canción, cambia
  /// el "me gusta" y sincroniza "Me encanta"). Si el "me gusta" cambió
  /// (`Ok`, o `Err(LikedPlaylistSyncFailure)` cuando solo falló "Me
  /// encanta", F5) recarga las favoritas y las playlists; el `Err` se
  /// devuelve igual para que la UI avise.
  Future<Result<Song>> toggle(Song song) async {
    final result = await ref.read(toggleLikeUseCaseProvider)(song);
    final likeChanged = switch (result) {
      Ok() => true,
      Err(failure: LikedPlaylistSyncFailure()) => true,
      Err() => false,
    };
    // Si la lista se desechó mientras tanto, este `ref` ya no se puede usar.
    if (likeChanged && ref.mounted) {
      // "Me encanta" es una playlist normal: su lista y su detalle se
      // recargan. No se sabe su id aquí, así que se invalida toda la familia
      // de detalles (solo se reconstruyen los que estén abiertos).
      ref
        ..invalidate(playlistsProvider)
        ..invalidate(playlistProvider)
        ..invalidateSelf();
    }
    return result;
  }
}
