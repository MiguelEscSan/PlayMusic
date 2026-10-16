import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';

/// Búsquedas recientes, la última primero.
final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de las búsquedas recientes: las carga y se recarga después de
/// apuntar, quitar o borrar (también tras un `Err`, por si la escritura se
/// quedó a medias). El `Err` se devuelve a quien llama.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async =>
      switch (await ref.watch(getRecentSearchesUseCaseProvider)()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

  Future<Result<Unit>> record(String query) =>
      _write(() => ref.read(recordSearchUseCaseProvider)(query));

  Future<Result<Unit>> remove(String query) =>
      _write(() => ref.read(removeRecentSearchUseCaseProvider)(query));

  Future<Result<Unit>> clear() =>
      _write(() => ref.read(clearRecentSearchesUseCaseProvider)());

  Future<Result<Unit>> _write(Future<Result<Unit>> Function() action) async {
    final result = await action();
    if (ref.mounted) ref.invalidateSelf();
    return result;
  }
}
