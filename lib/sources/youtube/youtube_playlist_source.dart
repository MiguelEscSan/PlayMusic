import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/sources/i_remote_playlist_source.dart';

import 'youtube_innertube.dart';

/// Lee playlists de YouTube. youtube_explode ya no sabe leer listas, así que
/// se piden a mano a la API interna de YouTube (`browse`), página a página.
class YoutubePlaylistSource implements IRemotePlaylistSource {
  YoutubePlaylistSource(this._innertube);

  /// Versión real. Crear el cliente no toca la red.
  factory YoutubePlaylistSource.create() =>
      YoutubePlaylistSource(YoutubeInnertube());

  final YoutubeInnertube _innertube;

  /// Acepta el enlace completo o solo el id.
  @override
  String? parsePlaylistId(String urlOrId) =>
      PlaylistId.parsePlaylistId(urlOrId);

  @override
  Future<RemoteSongPlaylist> fetch(
    String playlistId, {
    required int maxSongs,
  }) async {
    final first = parsePlaylistPage(
      await _innertube.post('browse', {'browseId': 'VL$playlistId'}),
    );
    final songs = [...first.songs];
    var token = first.continuation;
    while (token != null && songs.length < maxSongs) {
      final page = parsePlaylistPage(
        await _innertube.post('browse', {'continuation': token}),
      );
      // Una página vacía no avanza: se para para no quedarse en bucle.
      if (page.songs.isEmpty) break;
      songs.addAll(page.songs);
      token = page.continuation;
    }
    return (title: first.title ?? '', songs: songs);
  }
}

/// Una página de `browse` de una lista de YouTube.
typedef PlaylistPage = ({
  String? title,
  List<Song?> songs,
  String? continuation,
});

/// Lee una página de `browse`: la primera (con título) o una continuación.
/// Cada vídeo que no parezca una canción llega como null, para contarlo
/// como saltado. [PlaylistPage.continuation] es el token de la página
/// siguiente de vídeos (no el de las listas recomendadas que YouTube pone
/// al final).
PlaylistPage parsePlaylistPage(Map<String, dynamic> json) {
  final title = jsonAt(json, const [
    'metadata',
    'playlistMetadataRenderer',
    'title',
  ]);
  var items =
      jsonAt(json, const [
        'contents',
        'twoColumnBrowseResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
        0,
        'itemSectionRenderer',
        'contents',
      ]) ??
      jsonAt(json, const [
        'onResponseReceivedActions',
        0,
        'appendContinuationItemsAction',
        'continuationItems',
      ]);
  // Formato antiguo: los vídeos van dentro de un playlistVideoListRenderer.
  final oldList = jsonAt(items, const [
    0,
    'playlistVideoListRenderer',
    'contents',
  ]);
  if (oldList != null) items = oldList;

  final songs = <Song?>[];
  String? continuation;
  if (items is List) {
    for (final item in items) {
      if (item is! Map) continue;
      if (item['lockupViewModel'] case final Map lockup) {
        if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') continue;
        songs.add(_songFromLockup(lockup));
      } else if (item['playlistVideoRenderer'] case final Map r) {
        songs.add(_songFromRenderer(r));
      } else if (item['continuationItemViewModel'] case final Map c) {
        continuation = _string(
          jsonAt(c, const [
            'continuationCommand',
            'innertubeCommand',
            'continuationCommand',
            'token',
          ]),
        );
      } else if (item['continuationItemRenderer'] case final Map c) {
        continuation = _string(
          jsonAt(c, const [
            'continuationEndpoint',
            'continuationCommand',
            'token',
          ]),
        );
      }
    }
  }
  return (title: _string(title), songs: songs, continuation: continuation);
}

String? _string(Object? value) => value is String ? value : null;

Song? _songFromLockup(Map lockup) {
  final id = _string(lockup['contentId']);
  if (id == null) return null;
  final meta = lockup['metadata']?['lockupMetadataViewModel'];
  return innertubeSong(
    videoId: id,
    title: jsonText(jsonAt(meta, const ['title'])),
    author: jsonText(
      jsonAt(meta, const [
        'metadata',
        'contentMetadataViewModel',
        'metadataRows',
        0,
        'metadataParts',
        0,
        'text',
      ]),
    ),
    duration: _lockupDuration(lockup),
  );
}

/// La duración va en la etiqueta de la miniatura ("4:01").
Duration? _lockupDuration(Map lockup) {
  final overlays = jsonAt(lockup, const [
    'contentImage',
    'thumbnailViewModel',
    'overlays',
  ]);
  if (overlays is! List) return null;
  for (final overlay in overlays) {
    final badges = jsonAt(overlay, const [
      'thumbnailBottomOverlayViewModel',
      'badges',
    ]);
    if (badges is! List) continue;
    for (final badge in badges) {
      final text = jsonAt(badge, const ['thumbnailBadgeViewModel', 'text']);
      final duration = parseVideoLength(_string(text));
      if (duration != null) return duration;
    }
  }
  return null;
}

Song? _songFromRenderer(Map r) {
  final id = _string(r['videoId']);
  if (id == null) return null;
  final seconds = int.tryParse('${r['lengthSeconds']}');
  return innertubeSong(
    videoId: id,
    title: jsonText(r['title']),
    author: jsonText(jsonAt(r, const ['shortBylineText', 'runs', 0])),
    duration: seconds != null
        ? Duration(seconds: seconds)
        : parseVideoLength(jsonText(r['lengthText'])),
  );
}
