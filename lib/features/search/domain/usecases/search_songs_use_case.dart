import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/search_results_page.dart';
import 'package:koda/core/domain/sources/i_track_search.dart';

/// Busca canciones. `Ok` con la primera página; su `loadMore` (y el de las
/// siguientes) también devuelve `Result`. Sin conexión llega como
/// `Err(NetworkFailure)`; cualquier otro error, `Err(UnexpectedFailure)`.
final class SearchSongsUseCase {
  const SearchSongsUseCase(this._source);

  final ITrackSearch _source;

  Future<Result<SearchResultsPage>> call(String query) =>
      _guarded(() => _source.search(query));

  Future<Result<SearchResultsPage>> _guarded(
    Future<SearchPage> Function() fetch,
  ) => guard(() async => _wrap(await fetch()), onError: _failure);

  SearchResultsPage _wrap(SearchPage page) {
    final more = page.loadMore;
    return SearchResultsPage(
      page.songs,
      more == null ? null : () => _guarded(more),
    );
  }

  static Failure _failure(Object error, StackTrace stackTrace) {
    final text = error.toString();
    final offline =
        text.contains('SocketException') || text.contains('ClientException');
    return offline
        ? NetworkFailure('Sin conexión', cause: error, stackTrace: stackTrace)
        : UnexpectedFailure(
            'No se pudo buscar',
            cause: error,
            stackTrace: stackTrace,
          );
  }
}
