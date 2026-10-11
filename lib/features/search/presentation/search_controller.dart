import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/models/song.dart';
import '../data/search_source.dart';
import '../data/youtube_search_source.dart';

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

/// Búsqueda con debounce mientras se escribe y paginación infinita.
class SongSearchController extends Notifier<SearchState> {
  Timer? _debounce;

  /// Cada búsqueda nueva invalida las respuestas de las anteriores.
  int _generation = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  /// Llamado en cada pulsación de tecla.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 600), () => search(query));
  }

  Future<void> search(String query) async {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      state = const SearchState();
      return;
    }
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

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Sin conexión. Tus descargas siguen disponibles.';
    }
    return 'No se pudo buscar. Inténtalo de nuevo.';
  }
}
