import '../../../core/models/song.dart';

/// Una página de resultados. [loadMore] es null cuando no hay más.
class SearchPage {
  const SearchPage(this.songs, this.loadMore);

  final List<Song> songs;
  final Future<SearchPage> Function()? loadMore;
}

/// Origen de búsqueda (YouTube, Jamendo…). La UI solo conoce esta interfaz.
abstract interface class SearchSource {
  Future<SearchPage> search(String query);
}
