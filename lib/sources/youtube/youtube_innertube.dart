import 'package:dio/dio.dart';

import 'package:sponify/core/domain/entities/song.dart';

import 'youtube_track_search.dart';

/// Cliente mínimo de la API interna de YouTube (InnerTube), para lo que
/// youtube_explode ya no sabe leer (listas y Mix).
class YoutubeInnertube {
  YoutubeInnertube([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final Dio _dio;

  static const _clientVersion = '2.20261015.00.00';

  /// POST a `youtubei/v1/<endpoint>` con el contexto del cliente web.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://www.youtube.com/youtubei/v1/$endpoint?prettyPrint=false',
      data: {
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': _clientVersion,
            'hl': 'es',
            'gl': 'ES',
          },
        },
        ...body,
      },
    );
    return response.data ?? const {};
  }
}

/// Baja por [path] (claves de mapa o índices de lista); null si no existe.
Object? jsonAt(Object? node, List<Object> path) {
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

/// Texto de un nodo de YouTube: `simpleText`, `content`, `text` o `runs`.
String? jsonText(Object? node) {
  if (node is! Map) return null;
  final simple = node['simpleText'] ?? node['content'] ?? node['text'];
  if (simple is String) return simple;
  final runs = node['runs'];
  if (runs is List) {
    return runs.map((r) => r is Map ? r['text'] ?? '' : '').join();
  }
  return null;
}

/// "4:23" o "1:02:03".
Duration? parseVideoLength(String? text) {
  if (text == null) return null;
  final parts = text.trim().split(':').map(int.tryParse).toList();
  if (parts.length < 2 || parts.length > 3 || parts.contains(null)) {
    return null;
  }
  var seconds = 0;
  for (final p in parts) {
    seconds = seconds * 60 + p!;
  }
  return Duration(seconds: seconds);
}

/// Canción a partir de los datos sueltos de InnerTube; null si no lo parece
/// (sin duración o demasiado larga), como
/// [YoutubeTrackSearch.songFromVideo].
Song? innertubeSong({
  required String videoId,
  required String? title,
  required String? author,
  required Duration? duration,
}) {
  if (title == null || author == null || duration == null) return null;
  if (duration > YoutubeTrackSearch.maxDuration) return null;
  final artist = YoutubeTrackSearch.cleanArtist(_mainArtist(author));
  return Song(
    id: '', // se asigna al guardarla en la BD
    title: _withoutArtist(YoutubeTrackSearch.cleanTitle(title), artist),
    artist: artist,
    durationMs: duration.inMilliseconds,
    artworkUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    source: SongSource.youtube,
    sourceId: videoId,
  );
}

/// Con varios artistas la firma viene como "Shakira y 2 más" (hl=es).
String _mainArtist(String author) =>
    author.replaceFirst(RegExp(r' y \d+ más$'), '');

/// El título suele venir como "Artista - Canción", también con
/// colaboraciones: "Artista, Otro - Canción" o "Artista & Otro - …".
String _withoutArtist(String title, String artist) {
  final dash = title.indexOf(' - ');
  if (dash <= 0) return title;
  final first = title.substring(0, dash).split(RegExp(r',|&| ft\.| x ')).first;
  if (first.trim().toLowerCase() != artist.toLowerCase()) return title;
  final rest = title.substring(dash + 3).trim();
  return rest.isEmpty ? title : rest;
}
