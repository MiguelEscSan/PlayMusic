import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/sources/i_radio_source.dart';

import 'youtube_innertube.dart';
import 'youtube_track_search.dart';

/// Candidatas que se leen del Mix; luego se ordenan por gustos y se quedan
/// `RadioService.maxSongs`.
const _mixLimit = 40;

/// Radio de YouTube: el Mix de la semilla (la lista automática `RD<id>`, más
/// musical que las relacionadas).
///
/// youtube_explode no sabe leer listas, así que el Mix se pide a mano a la
/// API interna de YouTube (`next`). Si falla o viene vacío se prueba con las
/// relacionadas y, en último caso, con una búsqueda `<artista> mix`.
class YoutubeRadioSource implements IRadioSource {
  YoutubeRadioSource(this._yt, {Dio? dio}) : _innertube = YoutubeInnertube(dio);

  /// Versión real, con su propio cliente de youtube_explode_dart.
  factory YoutubeRadioSource.create() => YoutubeRadioSource(YoutubeExplode());

  final YoutubeExplode _yt;
  final YoutubeInnertube _innertube;

  @override
  SongSource get source => SongSource.youtube;

  @override
  Future<List<Song>> relatedTo(Song seed) async {
    try {
      final json = await _innertube.post('next', {
        'videoId': seed.sourceId,
        'playlistId': 'RD${seed.sourceId}',
      });
      final mix = parseMixSongs(json, seedId: seed.sourceId);
      if (mix.isNotEmpty) return mix;
    } catch (_) {
      // Sin Mix: se prueba con las relacionadas.
    }
    try {
      final songs = await _related(seed);
      if (songs.isNotEmpty) return songs;
    } catch (_) {
      // Sin relacionadas: se busca por artista.
    }
    final results = await _yt.search.search('${seed.artist} mix');
    return results
        .map(YoutubeTrackSearch.songFromVideo)
        .whereType<Song>()
        .where((s) => s.sourceId != seed.sourceId)
        .toList();
  }

  /// Relacionadas de YouTube (solo metadatos, sin streams).
  Future<List<Song>> _related(Song seed) async {
    final video = await _yt.videos.get(seed.sourceId);
    final related = await _yt.videos.getRelatedVideos(video);
    if (related == null) return const [];
    return related
        .map(YoutubeTrackSearch.songFromVideo)
        .whereType<Song>()
        .toList();
  }
}

/// Canciones del Mix en la respuesta de `next`, en su orden. Quita la
/// semilla y lo que no parezca una canción (sin duración o demasiado
/// largo), como [YoutubeTrackSearch.songFromVideo].
List<Song> parseMixSongs(
  Map<String, dynamic> json, {
  required String seedId,
  int limit = _mixLimit,
}) {
  final entries = jsonAt(json, const [
    'contents',
    'twoColumnWatchNextResults',
    'playlist',
    'playlist',
    'contents',
  ]);
  if (entries is! List) return const [];
  final songs = <Song>[];
  for (final entry in entries) {
    if (songs.length >= limit) break;
    final r = entry is Map ? entry['playlistPanelVideoRenderer'] : null;
    if (r is! Map) continue;
    final id = r['videoId'];
    if (id is! String || id == seedId) continue;
    final song = innertubeSong(
      videoId: id,
      title: jsonText(r['title']),
      author: jsonText(jsonAt(r, const ['longBylineText', 'runs', 0])),
      duration: parseVideoLength(jsonText(r['lengthText'])),
    );
    if (song != null) songs.add(song);
  }
  return songs;
}
