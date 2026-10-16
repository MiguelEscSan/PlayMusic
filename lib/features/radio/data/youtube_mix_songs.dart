import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../../search/data/youtube_search_source.dart';
import '../domain/radio_service.dart';
import 'youtube_related_songs.dart';

/// Candidatas que se leen del Mix; luego se ordenan por gustos y se quedan
/// [RadioService.maxSongs].
const _mixLimit = 40;

const _nextUrl = 'https://www.youtube.com/youtubei/v1/next?prettyPrint=false';
const _clientVersion = '2.20261015.00.00';

/// [RelatedSongsFetcher] real: el Mix de YouTube de la semilla (la lista
/// automática `RD<id>`, más musical que las relacionadas).
///
/// youtube_explode no sabe leer listas, así que el Mix se pide a mano a la
/// API interna de YouTube (`next`). Si falla o viene vacío se prueba con las
/// relacionadas y, en último caso, con una búsqueda `<artista> mix`.
RelatedSongsFetcher youtubeMixSongs(YoutubeExplode yt, {Dio? dio}) {
  final http =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
  final related = youtubeRelatedSongs(yt);
  return (seed) async {
    try {
      final mix = await _fetchMix(http, seed.sourceId);
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
        .map(YoutubeSearchSource.songFromVideo)
        .whereType<Song>()
        .where((s) => s.sourceId != seed.sourceId)
        .toList();
  };
}

Future<List<Song>> _fetchMix(Dio http, String videoId) async {
  final response = await http.post<Map<String, dynamic>>(
    _nextUrl,
    data: {
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': _clientVersion,
          'hl': 'es',
          'gl': 'ES',
        },
      },
      'videoId': videoId,
      'playlistId': 'RD$videoId',
    },
  );
  final json = response.data;
  if (json == null) return const [];
  return parseMixSongs(json, seedId: videoId);
}

/// Canciones del Mix en la respuesta de `next`, en su orden. Quita la
/// semilla y lo que no parezca una canción (sin duración o demasiado
/// largo), como [YoutubeSearchSource.songFromVideo].
List<Song> parseMixSongs(
  Map<String, dynamic> json, {
  required String seedId,
  int limit = _mixLimit,
}) {
  final entries = _at(json, const [
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
    final duration = _parseLength(_text(r['lengthText']));
    if (duration == null || duration > YoutubeSearchSource.maxDuration) {
      continue;
    }
    final title = _text(r['title']);
    final author = _text(_at(r, const ['longBylineText', 'runs', 0]));
    if (title == null || author == null) continue;
    final artist = YoutubeSearchSource.cleanArtist(_mainArtist(author));
    songs.add(
      Song(
        id: '', // se asigna al guardarla en la BD
        title: _withoutArtist(YoutubeSearchSource.cleanTitle(title), artist),
        artist: artist,
        durationMs: duration.inMilliseconds,
        artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
        source: SongSource.youtube,
        sourceId: id,
      ),
    );
  }
  return songs;
}

Object? _at(Object? node, List<Object> path) {
  for (final key in path) {
    if (key is String && node is Map) {
      node = node[key];
    } else if (key is int && node is List && key < node.length) {
      node = node[key];
    } else {
      return null;
    }
  }
  return node;
}

/// Texto de un nodo de YouTube: `simpleText`, `runs` o `text`.
String? _text(Object? node) {
  if (node is! Map) return null;
  final simple = node['simpleText'] ?? node['text'];
  if (simple is String) return simple;
  final runs = node['runs'];
  if (runs is List) {
    return runs.map((r) => r is Map ? r['text'] ?? '' : '').join();
  }
  return null;
}

/// "4:23" o "1:02:03".
Duration? _parseLength(String? text) {
  if (text == null) return null;
  final parts = text.trim().split(':').map(int.tryParse).toList();
  if (parts.isEmpty || parts.length > 3 || parts.contains(null)) return null;
  var seconds = 0;
  for (final p in parts) {
    seconds = seconds * 60 + p!;
  }
  return Duration(seconds: seconds);
}

/// En los Mix el título suele venir como "Artista - Canción".
/// Con colaboraciones: "Artista, Otro - Canción" o "Artista & Otro - …".
String _withoutArtist(String title, String artist) {
  final dash = title.indexOf(' - ');
  if (dash <= 0) return title;
  final first = title.substring(0, dash).split(RegExp(r',|&| ft\.| x ')).first;
  if (first.trim().toLowerCase() != artist.toLowerCase()) return title;
  final rest = title.substring(dash + 3).trim();
  return rest.isEmpty ? title : rest;
}

/// Con varios artistas la firma viene como "Shakira y 2 más" (hl=es).
String _mainArtist(String author) =>
    author.replaceFirst(RegExp(r' y \d+ más$'), '');
