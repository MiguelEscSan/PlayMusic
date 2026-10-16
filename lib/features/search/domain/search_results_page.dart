import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';

/// Una página de resultados de `SearchSongsUseCase`. [loadMore] es null
/// cuando no hay más; cuando la hay, nunca lanza: un fallo llega como `Err`.
class SearchResultsPage {
  const SearchResultsPage(this.songs, this.loadMore);

  final List<Song> songs;
  final Future<Result<SearchResultsPage>> Function()? loadMore;
}
