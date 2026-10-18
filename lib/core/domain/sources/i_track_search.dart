import 'package:sponify/core/domain/entities/song.dart';

/// Una página de resultados tal como la da un [ITrackSearch]. [loadMore] es
/// null cuando no hay más; puede lanzar (red), por eso la UI no la usa
/// directamente: pasa por `SearchSongsUseCase`, que da `SearchResultsPage`.
class SearchPage {
  const SearchPage(this.songs, this.loadMore);

  final List<Song> songs;
  final Future<SearchPage> Function()? loadMore;
}

/// Búsqueda de canciones en un origen (YouTube, Jamendo…). Puede lanzar si
/// falla la red.
abstract interface class ITrackSearch {
  Future<SearchPage> search(String query);
}
