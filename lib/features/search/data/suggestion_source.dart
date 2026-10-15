/// Sugerencias de búsqueda mientras se escribe. La UI solo conoce esta
/// interfaz.
abstract interface class SuggestionSource {
  Future<List<String>> suggestions(String query);
}
