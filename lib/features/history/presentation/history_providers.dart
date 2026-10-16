import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';

/// Más escuchadas de los últimos 30 días.
final topSongsProvider = AsyncNotifierProvider<TopSongsNotifier, List<Song>>(
  TopSongsNotifier.new,
  retry: noAutomaticRetry,
);

/// Lo escuchado recientemente.
final recentSongsProvider =
    AsyncNotifierProvider<RecentSongsNotifier, List<Song>>(
      RecentSongsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Base de las listas del historial: carga con su caso de uso y se recarga
/// cada vez que el historial cambia (`WatchHistoryChangedUseCase`: una
/// escucha guardada al empezar a sonar una canción, o el historial
/// borrado con `ClearHistoryUseCase`).
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
abstract class _HistoryListNotifier extends AsyncNotifier<List<Song>> {
  Future<Result<List<Song>>> load();

  @override
  Future<List<Song>> build() async {
    final changes = ref
        .watch(watchHistoryChangedUseCaseProvider)()
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);
    return switch (await load()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}

class TopSongsNotifier extends _HistoryListNotifier {
  @override
  Future<Result<List<Song>>> load() => ref.watch(getTopSongsUseCaseProvider)();
}

class RecentSongsNotifier extends _HistoryListNotifier {
  @override
  Future<Result<List<Song>>> load() =>
      ref.watch(getRecentSongsUseCaseProvider)();
}
