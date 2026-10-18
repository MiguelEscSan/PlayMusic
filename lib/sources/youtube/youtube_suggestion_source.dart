import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:sponify/features/search/domain/suggestion_source.dart';

/// Autocompletado de YouTube con youtube_explode_dart.
class YoutubeSuggestionSource implements SuggestionSource {
  YoutubeSuggestionSource(this._yt);

  /// Versión real, con su propio cliente de youtube_explode_dart; hay que
  /// cerrarla con [close].
  factory YoutubeSuggestionSource.create() =>
      YoutubeSuggestionSource(YoutubeExplode());

  final YoutubeExplode _yt;

  void close() => _yt.close();

  @override
  Future<List<String>> suggestions(String query) =>
      _yt.search.getQuerySuggestions(query);
}
