import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/data/youtube_playlist_importer.dart';
import 'package:sponify/features/search/data/youtube_innertube.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Respuestas reales de `youtubei/v1/browse` para "Top 500 Classic Rock
/// songs", recortadas: la primera página (3 vídeos) y la última
/// continuación (2 vídeos).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _firstPage() => _load('youtube_playlist_page');
Map<String, dynamic> _lastPage() => _load('youtube_playlist_continuation');

List<dynamic> _firstItems(Map<String, dynamic> json) =>
    json['contents']['twoColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'][0]['itemSectionRenderer']['contents']
        as List<dynamic>;

Map<String, dynamic> _lockup(Map<String, dynamic> json, int i) =>
    _firstItems(json)[i]['lockupViewModel'] as Map<String, dynamic>;

/// Cambia la etiqueta de duración del vídeo [i] de la primera página.
void _setLength(Map<String, dynamic> json, int i, String text) {
  final overlays =
      _lockup(json, i)['contentImage']['thumbnailViewModel']['overlays']
          as List<dynamic>;
  overlays.first['thumbnailBottomOverlayViewModel']['badges'][0]['thumbnailBadgeViewModel']['text'] =
      text;
}

/// Responde a `browse` con páginas preparadas, por token.
class _FakeInnertube extends YoutubeInnertube {
  _FakeInnertube(this.pages);

  final Map<String, Map<String, dynamic>> pages;
  final requests = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    requests.add(body);
    final key = (body['browseId'] ?? body['continuation']) as String;
    return pages[key] ?? const {};
  }
}

void main() {
  group('parsePlaylistPage', () {
    test('lee el título, las canciones y el token de la siguiente página', () {
      final page = parsePlaylistPage(_firstPage());

      expect(page.title, 'Top 500 Classic Rock songs');
      expect(page.songs.map((s) => s?.sourceId), [
        'fJ9rUzIMcZQ',
        'gEPmA3USJdI',
        'CD-E-LDc384',
      ]);
      final acdc = page.songs[1]!;
      expect(
        acdc.title,
        'Highway to Hell (Live At River Plate, December 2009)',
      );
      expect(acdc.artist, 'AC/DC');
      expect(
        acdc.durationMs,
        const Duration(minutes: 4, seconds: 45).inMilliseconds,
      );
      expect(
        acdc.artworkUrl,
        'https://i.ytimg.com/vi/gEPmA3USJdI/hqdefault.jpg',
      );
      expect(page.songs[2]!.title, 'Metallica: Enter Sandman');
      // El token es el de los vídeos, no el de las listas recomendadas.
      final itemsToken = _firstItems(
        _firstPage(),
      ).last['continuationItemViewModel']['continuationCommand']['innertubeCommand']['continuationCommand']['token'];
      expect(page.continuation, itemsToken);
    });

    test('lee una página de continuación', () {
      final page = parsePlaylistPage(_lastPage());

      expect(page.title, isNull);
      expect(page.songs.map((s) => s?.sourceId), [
        'XsGl-0pzEEc',
        'GzZWSrr5wFI',
      ]);
      expect(page.songs.first!.artist, 'Thin Lizzy Official');
      expect(page.continuation, isNull);
    });

    test('lo que no parece canción llega como null', () {
      final json = _firstPage();
      _setLength(json, 0, 'EN DIRECTO');
      _setLength(json, 1, '21:00');

      final page = parsePlaylistPage(json);

      expect(page.songs, hasLength(3));
      expect(page.songs[0], isNull);
      expect(page.songs[1], isNull);
      expect(page.songs[2], isNotNull);
    });

    test('ignora lo que no es un vídeo', () {
      final json = _firstPage();
      _lockup(json, 0)['contentType'] = 'LOCKUP_CONTENT_TYPE_PLAYLIST';

      expect(parsePlaylistPage(json).songs, hasLength(2));
    });

    test('entiende el formato antiguo (playlistVideoRenderer)', () {
      final page = parsePlaylistPage({
        'onResponseReceivedActions': [
          {
            'appendContinuationItemsAction': {
              'continuationItems': [
                {
                  'playlistVideoRenderer': {
                    'videoId': 'abc',
                    'title': {
                      'runs': [
                        {'text': 'Queen - Bohemian Rhapsody'},
                      ],
                    },
                    'shortBylineText': {
                      'runs': [
                        {'text': 'Queen'},
                      ],
                    },
                    'lengthSeconds': '355',
                  },
                },
                {
                  'continuationItemRenderer': {
                    'continuationEndpoint': {
                      'continuationCommand': {'token': 'next'},
                    },
                  },
                },
              ],
            },
          },
        ],
      });

      expect(page.songs.single!.title, 'Bohemian Rhapsody');
      expect(page.songs.single!.durationMs, 355000);
      expect(page.continuation, 'next');
    });
  });

  group('YoutubePlaylistImporter.youtube', () {
    sqfliteFfiInit();
    late AppDatabase db;
    late PlaylistRepositoryImpl repo;

    setUp(() async {
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      repo = PlaylistRepositoryImpl(PlaylistDao(db, SongDao(db)));
    });

    tearDown(() => db.close());

    test('sigue las páginas hasta el final', () async {
      final first = _firstPage();
      final token = parsePlaylistPage(first).continuation!;
      final innertube = _FakeInnertube({
        'VLPL0GvsLQil0MmYC96KEs_7dTNsLm1PS6JX': first,
        token: _lastPage(),
      });
      final importer = YoutubePlaylistImporter.youtube(repo, innertube);

      final result = await importer.importFromUrl(
        'https://www.youtube.com/playlist?list=PL0GvsLQil0MmYC96KEs_7dTNsLm1PS6JX',
      );

      final imported = (result as Ok).value;
      expect(imported.imported, 5);
      expect(innertube.requests, [
        {'browseId': 'VLPL0GvsLQil0MmYC96KEs_7dTNsLm1PS6JX'},
        {'continuation': token},
      ]);
      final playlist = (await repo.findById(imported.playlistId) as Ok).value;
      expect(playlist.name, 'Top 500 Classic Rock songs');
    });

    test('para si una página no trae canciones', () async {
      final first = _firstPage();
      final token = parsePlaylistPage(first).continuation!;
      final innertube = _FakeInnertube({
        'VLPL0GvsLQil0MmYC96KEs_7dTNsLm1PS6JX': first,
      });
      final importer = YoutubePlaylistImporter.youtube(repo, innertube);

      final result = await importer.importFromUrl(
        'PL0GvsLQil0MmYC96KEs_7dTNsLm1PS6JX',
      );

      expect((result as Ok).value.imported, 3);
      expect(innertube.requests, hasLength(2));
      expect(innertube.requests.last, {'continuation': token});
    });
  });
}
