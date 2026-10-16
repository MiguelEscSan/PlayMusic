import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repository_providers.dart';
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
/// El único que escribe "me gusta" es `SongActions.toggleLike`, que la
/// invalida al cambiar una canción; no hay más fuentes de cambios.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class LikedSongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final repository = ref.watch(songRepositoryProvider);
    return switch (await repository.getLiked()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
