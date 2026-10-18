import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../search/data/youtube_search_source.dart';
import '../domain/i_track_matcher.dart';
import '../domain/remote_playlist.dart';
import 'track_match_scoring.dart';

/// Busca candidatos para un texto. Puede lanzar si falla la red.
typedef CandidateSearch = Future<List<MatchCandidate>> Function(String query);

/// Empareja pistas de otro servicio con vídeos de YouTube: busca
/// "artista título" y se queda con el mejor candidato según
/// [pickBestMatch] (duración, título, canal oficial, sin directos).
class YoutubeTrackMatcher implements ITrackMatcher {
  YoutubeTrackMatcher(this._search);

  /// Versión real, con la búsqueda de youtube_explode que usa la app.
  factory YoutubeTrackMatcher.youtube(YoutubeExplode yt) =>
      YoutubeTrackMatcher((query) async {
        final videos = await yt.search.search(query);
        return [
          for (final v in videos.take(maxCandidates))
            if (YoutubeSearchSource.songFromVideo(v) case final song?)
              MatchCandidate(
                title: v.title,
                channel: v.author,
                duration: v.duration,
                isLive: v.isLive,
                song: song,
              ),
        ];
      });

  /// Resultados que se miran por pista: los primeros suelen ser los buenos.
  static const maxCandidates = 10;

  final CandidateSearch _search;

  @override
  Future<Result<Song?>> match(RemoteTrack track) async {
    final List<MatchCandidate> candidates;
    try {
      candidates = await _search(matchQuery(track));
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
}
