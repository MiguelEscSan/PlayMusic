import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/i_search_history_repository.dart';

/// Apunta una búsqueda enviada como la más reciente.
final class RecordSearchUseCase {
  const RecordSearchUseCase(this._history);

  final ISearchHistoryRepository _history;

  Future<Result<Unit>> call(String query) => _history.record(query);
}
