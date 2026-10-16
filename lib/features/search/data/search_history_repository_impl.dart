import 'package:sponify/core/data/repositories/guard.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/search/data/search_history_dao.dart';
import 'package:sponify/features/search/domain/i_search_history_repository.dart';

/// [ISearchHistoryRepository] sobre la tabla `search_history`
/// ([SearchHistoryDao]).
class SearchHistoryRepositoryImpl implements ISearchHistoryRepository {
  SearchHistoryRepositoryImpl(this._dao);

  final SearchHistoryDao _dao;

  @override
  Future<Result<List<String>>> recent() => guard(_dao.recent);

  @override
  Future<Result<Unit>> record(String query) => _write(() => _dao.record(query));

  @override
  Future<Result<Unit>> remove(String query) => _write(() => _dao.remove(query));

  @override
  Future<Result<Unit>> clear() => _write(_dao.clear);

  Future<Result<Unit>> _write(Future<void> Function() action) =>
      guard(() async {
        await action();
        return unit;
      });
}
