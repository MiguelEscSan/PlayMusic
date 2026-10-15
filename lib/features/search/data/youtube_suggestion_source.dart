import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'suggestion_source.dart';

/// Autocompletado de YouTube con youtube_explode_dart.
class YoutubeSuggestionSource implements SuggestionSource {
  YoutubeSuggestionSource(this._yt);

  final YoutubeExplode _yt;

  @override
  Future<List<String>> suggestions(String query) =>
      _yt.search.getQuerySuggestions(query);
}
