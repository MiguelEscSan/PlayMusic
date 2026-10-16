import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../di/providers.dart';
import '../domain/search_results_page.dart';
import 'search_history_providers.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMore,
  });

  final String query;
  final List<Song> results;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Future<Result<SearchResultsPage>> Function()? loadMore;

  bool get hasMore => loadMore != null;
}

final searchControllerProvider =
    NotifierProvider<SongSearchController, SearchState>(
      SongSearchController.new,
    );

/// Búsqueda con paginación infinita. Cada búsqueda enviada se guarda en el
/// historial; mientras se escribe la pantalla solo muestra sugerencias.
class SongSearchController extends Notifier<SearchState> {
  /// Cada búsqueda nueva invalida las respuestas de las anteriores.
  int _generation = 0;

  @override
  SearchState build() => const SearchState();

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = const SearchState();
      return;
    }
    unawaited(_remember(q));
    if (q == state.query && state.results.isNotEmpty) return;

    final generation = ++_generation;
    state = SearchState(query: q, isLoading: true);
    final result = await ref.read(searchSongsUseCaseProvider)(q);
    if (generation != _generation) return;
    state = switch (result) {
      Ok(value: final page) => SearchState(
        query: q,
        results: page.songs,
        loadMore: page.loadMore,
      ),
      Err(:final failure) => SearchState(query: q, error: _describe(failure)),
    };
  }

  Future<void> loadMore() async {
    final more = state.loadMore;
    if (more == null || state.isLoadingMore || state.isLoading) return;
    final generation = _generation;
    state = SearchState(
      query: state.query,
      results: state.results,
      isLoadingMore: true,
      loadMore: more,
    );
    final result = await more();
    if (generation != _generation) return;
    switch (result) {
      case Ok(value: final page):
        final seen = state.results.toSet();
        state = SearchState(
          query: state.query,
          results: [...state.results, ...page.songs.where(seen.add)],
          loadMore: page.loadMore,
        );
      case Err(:final failure):
        state = SearchState(
          query: state.query,
          results: state.results,
          loadMore: more,
          error: _describe(failure),
        );
    }
  }

  Future<void> retry() {
    final q = state.query;
    state = const SearchState();
    return search(q);
  }

  /// Guardar el historial nunca debe estropear la búsqueda: un `Err` se
  /// ignora.
  Future<void> _remember(String query) async {
    await ref.read(recentSearchesProvider.notifier).record(query);
  }

  String _describe(Failure failure) => switch (failure) {
    NetworkFailure() => 'Sin conexión. Tus descargas siguen disponibles.',
    _ => 'No se pudo buscar. Inténtalo de nuevo.',
  };
}
