/// Sugerencias de búsqueda mientras se escribe. Puede lanzar si falla la
/// red; la UI pasa por `GetSuggestionsUseCase`.
abstract interface class SuggestionSource {
  Future<List<String>> suggestions(String query);
}
