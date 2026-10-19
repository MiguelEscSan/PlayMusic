import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/i_search_history_repository.dart';

/// Quita una búsqueda de las recientes.
final class RemoveRecentSearchUseCase {
  const RemoveRecentSearchUseCase(this._history);

  final ISearchHistoryRepository _history;

  Future<Result<Unit>> call(String query) => _history.remove(query);
}
