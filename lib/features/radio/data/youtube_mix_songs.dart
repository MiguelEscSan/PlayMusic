import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';

import 'package:sponify/sources/youtube/youtube_innertube.dart';
import 'package:sponify/sources/youtube/youtube_track_search.dart';

import '../domain/radio_service.dart';
import 'youtube_related_songs.dart';

/// Candidatas que se leen del Mix; luego se ordenan por gustos y se quedan
/// [RadioService.maxSongs].
const _mixLimit = 40;

/// [RelatedSongsFetcher] real: el Mix de YouTube de la semilla (la lista
/// automática `RD<id>`, más musical que las relacionadas).
///
/// youtube_explode no sabe leer listas, así que el Mix se pide a mano a la
/// API interna de YouTube (`next`). Si falla o viene vacío se prueba con las
/// relacionadas y, en último caso, con una búsqueda `<artista> mix`.
RelatedSongsFetcher youtubeMixSongs(YoutubeExplode yt, {Dio? dio}) {
  final innertube = YoutubeInnertube(dio);
  final related = youtubeRelatedSongs(yt);
  return (seed) async {
    try {
      final json = await innertube.post('next', {
        'videoId': seed.sourceId,
        'playlistId': 'RD${seed.sourceId}',
      });
      final mix = parseMixSongs(json, seedId: seed.sourceId);
      if (mix.isNotEmpty) return mix;
    } catch (_) {
      // Sin Mix: se prueba con las relacionadas.
    }
    try {
      final songs = await related(seed);
      if (songs.isNotEmpty) return songs;
    } catch (_) {
      // Sin relacionadas: se busca por artista.
    }
    final results = await yt.search.search('${seed.artist} mix');
    return results
        .map(YoutubeTrackSearch.songFromVideo)
        .whereType<Song>()
        .where((s) => s.sourceId != seed.sourceId)
        .toList();
  };
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
