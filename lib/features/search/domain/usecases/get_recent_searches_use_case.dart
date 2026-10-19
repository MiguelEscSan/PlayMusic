import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/i_search_history_repository.dart';

/// Búsquedas recientes, la última primero.
final class GetRecentSearchesUseCase {
  const GetRecentSearchesUseCase(this._history);

  final ISearchHistoryRepository _history;

  Future<Result<List<String>>> call() => _history.recent();
}
