import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';

final searchSuggestionsProvider =
    NotifierProvider<SearchSuggestionsController, List<String>>(
      SearchSuggestionsController.new,
    );

/// Sugerencias mientras se escribe, con debounce. Los errores (sin red,
/// respuesta rara…) simplemente dejan la lista vacía.
class SearchSuggestionsController extends Notifier<List<String>> {
  static const debounce = Duration(milliseconds: 300);
  static const maxSuggestions = 8;

  Timer? _debounce;

  /// Cada texto nuevo invalida las respuestas de los anteriores.
  int _generation = 0;

  @override
  List<String> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  /// Llamado en cada pulsación de tecla.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    final generation = ++_generation;
    final q = query.trim();
    if (q.isEmpty) {
      state = const [];
      return;
    }
    _debounce = Timer(debounce, () => _fetch(q, generation));
  }

  /// Olvida las sugerencias (p. ej. al enviar la búsqueda).
  void clear() {
    _debounce?.cancel();
    _generation++;
    state = const [];
  }

  Future<void> _fetch(String query, int generation) async {
    List<String> result;
    try {
      result = await ref.read(suggestionSourceProvider).suggestions(query);
    } catch (_) {
      result = const [];
    }
    if (generation != _generation) return;
    state = result.take(maxSuggestions).toList();
  }
}
