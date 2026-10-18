/// Lectura pura del HTML público de Spotify. Todo el conocimiento del
/// formato de sus páginas vive aquí: si Spotify cambia, solo cambia este
/// archivo (y sus fixtures de test).
library;

import 'dart:convert';

import '../domain/remote_playlist.dart';

final _nextData = RegExp(
  r'<script[^>]*\bid="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
);

final _songCountMeta = RegExp(
  r'''<meta[^>]*\bname=["']music:song_count["'][^>]*\bcontent=["'](\d+)["']''',
);

final _initialState = RegExp(
  r'<script[^>]*\bid="initialState"[^>]*>([\s\S]*?)</script>',
);

final _totalCountJson = RegExp(r'"totalCount"\s*:\s*(\d+)');

/// Lee la página `open.spotify.com/embed/playlist/<id>`: el JSON de
/// `__NEXT_DATA__` trae el nombre y hasta 100 pistas, pero no el total
/// ([RemotePlaylist.totalCount] queda en null).
///
/// Lanza [FormatException] si la página no tiene el formato esperado.
RemotePlaylist parseSpotifyEmbed(String html) {
  final match = _nextData.firstMatch(html);
  if (match == null) {
    throw const FormatException('La página de Spotify no trae __NEXT_DATA__');
  }
  final Object? json;
  try {
    json = jsonDecode(match.group(1)!);
  } on FormatException {
    throw const FormatException('El __NEXT_DATA__ de Spotify no es JSON');
  }
  final entity = _at(json, const [
    'props',
    'pageProps',
    'state',
    'data',
    'entity',
  ]);
  final list = _at(entity, const ['trackList']);
  if (entity is! Map || list is! List) {
    throw const FormatException('El JSON de Spotify no trae la lista');
  }

  final tracks = <RemoteTrack>[];
  for (final item in list) {
    if (item is! Map) continue;
    final title = item['title'];
    final duration = item['duration'];
    if (title is! String || title.trim().isEmpty || duration is! num) {
      continue;
    }
    final subtitle = item['subtitle'];
    tracks.add(
      RemoteTrack(
        title: title.trim(),
        artists: subtitle is String ? _splitArtists(subtitle) : const [],
        durationMs: duration.toInt(),
      ),
    );
  }
  final name = entity['name'] ?? entity['title'];
  return RemotePlaylist(
    name: name is String ? name.trim() : '',
    tracks: tracks,
  );
}

/// Lee el número total de pistas de la página pública
/// `open.spotify.com/playlist/<id>` (pedida como un rastreador; con un
/// navegador normal llega vacía). Primero la meta `music:song_count`; si no
/// está, el `totalCount` del `initialState` (JSON en base64). Null si no
/// aparece por ningún lado. Nunca lanza.
int? parseSpotifyTotalCount(String html) {
  if (_songCountMeta.firstMatch(html) case final m?) {
    return int.tryParse(m.group(1)!);
  }
  if (_initialState.firstMatch(html) case final m?) {
    try {
      final decoded = utf8.decode(
        base64.decode(base64.normalize(m.group(1)!.trim())),
      );
      if (_totalCountJson.firstMatch(decoded) case final t?) {
        return int.tryParse(t.group(1)!);
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// "Romeo Santos, Prince Royce" → ["Romeo Santos", "Prince Royce"].
List<String> _splitArtists(String subtitle) => [
  for (final part in subtitle.replaceAll(' ', ' ').split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

Object? _at(Object? json, List<String> path) {
  var node = json;
  for (final key in path) {
    if (node is! Map) return null;
    node = node[key];
  }
  return node;
}
