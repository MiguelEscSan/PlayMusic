import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../search/data/youtube_innertube.dart';
import '../domain/i_playlist_importer.dart';

/// Descarga el título y los vídeos de una playlist de YouTube. Cada vídeo
/// que no parezca una canción (directo, sin duración…) llega como null.
typedef YoutubePlaylistFetcher =
    Future<(String title, List<Song?> songs)> Function(String playlistId);

/// Crea una playlist local a partir de una de YouTube, con el mismo título y
/// las canciones en el mismo orden.
class YoutubePlaylistImporter implements IPlaylistImporter {
  YoutubePlaylistImporter(this._playlists, this._fetch);

  /// Versión real. youtube_explode ya no sabe leer listas, así que se piden
  /// a mano a la API interna de YouTube (`browse`), página a página.
  factory YoutubePlaylistImporter.youtube(
    IPlaylistRepository playlists,
    YoutubeInnertube innertube,
  ) => YoutubePlaylistImporter(playlists, (id) async {
    final first = parsePlaylistPage(
      await innertube.post('browse', {'browseId': 'VL$id'}),
    );
    final songs = [...first.songs];
    var token = first.continuation;
    while (token != null && songs.length < maxSongs) {
      final page = parsePlaylistPage(
        await innertube.post('browse', {'continuation': token}),
      );
      // Una página vacía no avanza: se para para no quedarse en bucle.
      if (page.songs.isEmpty) break;
      songs.addAll(page.songs);
      token = page.continuation;
    }
    return (first.title ?? '', songs);
  });

  /// Límite de canciones por importación, para no eternizarse.
  static const maxSongs = 500;

  final IPlaylistRepository _playlists;
  final YoutubePlaylistFetcher _fetch;

  /// Acepta el enlace completo o solo el id. Nunca lanza:
  /// `Err(InvalidPlaylistLinkFailure)` si no es válido,
  /// `Err(NetworkFailure)` si no se puede leer de YouTube y
  /// `Err(EmptyPlaylistFailure)` si no hay nada que importar; en esos casos
  /// no se crea ninguna playlist. Un fallo al guardar llega como su `Err`
  /// (la playlist puede quedar a medias, como antes).
  @override
  Future<Result<ImportResult>> importFromUrl(
    String urlOrId, {
    ImportProgress? onProgress,
  }) async {
    final id = PlaylistId.parsePlaylistId(urlOrId.trim());
    if (id == null) return const Err(InvalidPlaylistLinkFailure());

    final String title;
    final List<Song?> fetched;
    try {
      (title, fetched) = await _fetch(id);
    } catch (e, st) {
      return Err(
        NetworkFailure(
          'No se pudo leer la playlist de YouTube',
          cause: e,
          stackTrace: st,
        ),
      );
    }
    final videos = fetched.take(maxSongs).toList();
    if (videos.every((s) => s == null)) {
      return const Err(EmptyPlaylistFailure());
    }

    final name = title.trim().isEmpty ? 'Playlist de YouTube' : title;
    final String playlistId;
    switch (await _playlists.create(name)) {
      case Ok(:final value):
        playlistId = value.id;
      case Err(:final failure):
        return Err(failure);
    }
    var imported = 0;
    onProgress?.call(0, videos.length);
    for (var i = 0; i < videos.length; i++) {
      if (videos[i] case final song?) {
        switch (await _playlists.addSong(playlistId, song)) {
          case Ok(value: true):
            imported++;
          case Ok(value: false):
            break; // Repetida.
          case Err(:final failure):
            return Err(failure);
        }
      }
      onProgress?.call(i + 1, videos.length);
    }
    return Ok(
      ImportResult(
        playlistId: playlistId,
        imported: imported,
        skipped: videos.length - imported,
      ),
    );
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
