import '../../../core/domain/entities/song.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';

import 'package:sponify/sources/youtube/youtube_innertube.dart';

import '../domain/i_track_matcher.dart';
import '../domain/remote_playlist.dart';
import 'track_match_scoring.dart';

/// Busca candidatos para un texto. Puede lanzar si falla la red.
typedef CandidateSearch = Future<List<MatchCandidate>> Function(String query);

/// Empareja pistas de otro servicio con vídeos de YouTube: busca
/// "artista título" y se queda con el mejor candidato según
/// [pickBestMatch] (duración, título, canal oficial, sin directos).
class YoutubeTrackMatcher implements ITrackMatcher {
  YoutubeTrackMatcher(
    this._search, {
    this.retryDelay = const Duration(seconds: 1),
  });

  /// Versión real, con la API interna de YouTube (la misma que usa la app
  /// para leer listas). La búsqueda HTML de youtube_explode no sirve aquí:
  /// tras unas 20 búsquedas seguidas YouTube la bloquea por abuso.
  factory YoutubeTrackMatcher.youtube(YoutubeInnertube innertube) =>
      YoutubeTrackMatcher(innertubeCandidateSearch(innertube));

  /// Búsqueda real de candidatos: solo vídeos (`params` = filtro "Vídeos").
  static CandidateSearch innertubeCandidateSearch(YoutubeInnertube innertube) =>
      (query) async => parseInnertubeSearch(
        await innertube.post('search', {
          'query': query,
          'params': 'EgIQAQ%3D%3D',
        }),
      ).take(maxCandidates).toList();

  /// Resultados que se miran por pista: los primeros suelen ser los buenos.
  static const maxCandidates = 10;

  /// Espera antes de reintentar una búsqueda fallida (un reintento).
  final Duration retryDelay;

  final CandidateSearch _search;

  @override
  Future<Result<Song?>> match(RemoteTrack track) async {
    final query = matchQuery(track);
    final List<MatchCandidate> candidates;
    try {
      candidates = await _searchWithRetry(query);
    } catch (e, st) {
      return Err(
        NetworkFailure(
          'No se pudo buscar la canción en YouTube',
          cause: e,
          stackTrace: st,
        ),
      );
    }
    final best = pickBestMatch(track, candidates);
    if (best == null) return const Ok(null);
    // Los datos de Spotify son más limpios que el título del vídeo.
    return Ok(
      best.song.copyWith(
        title: track.title,
        artist: track.artists.isEmpty ? null : track.artists.join(', '),
      ),
    );
  }

  Future<List<MatchCandidate>> _searchWithRetry(String query) async {
    try {
      return await _search(query);
    } catch (_) {
      await Future<void>.delayed(retryDelay);
      return _search(query);
    }
  }
}

/// Lee los vídeos de una respuesta de `youtubei/v1/search`, en orden, con el
/// título y el canal en bruto. Salta lo que no es un vídeo, los directos y
/// lo que no parece una canción (sin duración o demasiado largo). Nunca
/// lanza: un JSON inesperado da una lista vacía.
List<MatchCandidate> parseInnertubeSearch(Map<String, dynamic> json) {
  final sections = jsonAt(json, const [
    'contents',
    'twoColumnSearchResultsRenderer',
    'primaryContents',
    'sectionListRenderer',
    'contents',
  ]);
  if (sections is! List) return const [];
  final candidates = <MatchCandidate>[];
  for (final section in sections) {
    final items = jsonAt(section, const ['itemSectionRenderer', 'contents']);
    if (items is! List) continue;
    for (final item in items) {
      final video = jsonAt(item, const ['videoRenderer']);
      if (video is! Map) continue;
      final id = video['videoId'];
      if (id is! String) continue;
      final title = jsonText(video['title']);
      final channel = jsonText(
        jsonAt(video, const ['ownerText', 'runs', 0]) ??
            jsonAt(video, const ['longBylineText', 'runs', 0]),
      );
      final duration = parseVideoLength(jsonText(video['lengthText']));
      if (_isLive(video)) continue;
      final song = innertubeSong(
        videoId: id,
        title: title,
        author: channel,
        duration: duration,
      );
      if (song == null) continue;
      candidates.add(
        MatchCandidate(
          title: title!,
          channel: channel!,
          duration: duration,
          isLive: false,
          song: song,
        ),
      );
    }
  }
  return candidates;
}

bool _isLive(Map video) {
  final badges = video['badges'];
  if (badges is! List) return false;
  return badges.any(
    (b) =>
        jsonAt(b, const ['metadataBadgeRenderer', 'style']) ==
        'BADGE_STYLE_TYPE_LIVE_NOW',
  );
}
