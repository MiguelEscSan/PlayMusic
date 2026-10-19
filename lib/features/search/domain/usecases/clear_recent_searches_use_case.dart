import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/i_search_history_repository.dart';

/// Borra todas las búsquedas recientes.
final class ClearRecentSearchesUseCase {
  const ClearRecentSearchesUseCase(this._history);

  final ISearchHistoryRepository _history;

  Future<Result<Unit>> call() => _history.clear();
}
