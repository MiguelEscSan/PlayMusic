import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../data/search_source.dart';
import '../data/youtube_search_source.dart';
import 'search_history_providers.dart';

final searchSourceProvider = Provider<SearchSource>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return YoutubeSearchSource(yt);
});

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
  final Future<SearchPage> Function()? loadMore;

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
    try {
      final page = await ref.read(searchSourceProvider).search(q);
      if (generation != _generation) return;
      state = SearchState(
        query: q,
        results: page.songs,
        loadMore: page.loadMore,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = SearchState(query: q, error: _describe(e));
    }
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
    try {
      final page = await more();
      if (generation != _generation) return;
      final seen = state.results.toSet();
      state = SearchState(
        query: state.query,
        results: [...state.results, ...page.songs.where(seen.add)],
        loadMore: page.loadMore,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = SearchState(
        query: state.query,
        results: state.results,
        loadMore: more,
        error: _describe(e),
      );
    }
  }

  Future<void> retry() {
    final q = state.query;
    state = const SearchState();
    return search(q);
  }

  /// Guardar el historial nunca debe estropear la búsqueda.
  Future<void> _remember(String query) async {
    try {
      await ref.read(searchHistoryDaoProvider).record(query);
    } catch (_) {}
  }

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Sin conexión. Tus descargas siguen disponibles.';
    }
    return 'No se pudo buscar. Inténtalo de nuevo.';
  }
}
