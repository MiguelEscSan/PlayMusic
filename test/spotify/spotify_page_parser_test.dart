import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koda/features/playlists/data/spotify_page_parser.dart';
import 'package:koda/features/playlists/domain/remote_playlist.dart';

String _fixture(String name) =>
    File('test/fixtures/spotify/$name').readAsStringSync();

void main() {
  group('parseSpotifyEmbed', () {
    test('lee el nombre y las pistas de __NEXT_DATA__', () {
      final playlist = parseSpotifyEmbed(_fixture('embed_playlist.html'));

      expect(playlist.name, '15 Marzo');
      expect(playlist.totalCount, isNull);
      expect(playlist.tracks, const [
        RemoteTrack(
          title: 'I Wanna Be Yours',
          artists: ['Arctic Monkeys'],
          durationMs: 183956,
        ),
        RemoteTrack(
          title: 'Dardos',
          artists: ['Romeo Santos', 'Prince Royce'],
          durationMs: 243070,
        ),
        RemoteTrack(
          title: 'Moves Like Jagger',
          artists: ['Maroon 5', 'Christina Aguilera'],
          durationMs: 202640,
        ),
      ]);
    });

    test('salta pistas sin título o sin duración', () {
      final html = _embed({
        'name': 'Mix',
        'trackList': [
          {'title': 'Buena', 'subtitle': 'A', 'duration': 1000},
          {'title': '', 'subtitle': 'B', 'duration': 1000},
          {'title': 'Sin duración', 'subtitle': 'C'},
          'basura',
        ],
      });
      final playlist = parseSpotifyEmbed(html);
      expect(playlist.tracks.map((t) => t.title), ['Buena']);
    });

    test('separa artistas con espacio duro y quita vacíos', () {
      final html = _embed({
        'name': 'Mix',
        'trackList': [
          {'title': 'X', 'subtitle': 'A, B , ,C', 'duration': 1},
        ],
      });
      expect(parseSpotifyEmbed(html).tracks.single.artists, ['A', 'B', 'C']);
    });

    test('lanza FormatException si no hay __NEXT_DATA__', () {
      expect(
        () => parseSpotifyEmbed('<html><body>nada</body></html>'),
        throwsFormatException,
      );
    });

    test('lanza FormatException si el JSON no tiene la lista', () {
      expect(
        () => parseSpotifyEmbed(
          '<script id="__NEXT_DATA__" type="application/json">{"props":{}}'
          '</script>',
        ),
        throwsFormatException,
      );
    });
  });

  group('parseSpotifyTotalCount', () {
    test('lee la meta music:song_count', () {
      expect(
        parseSpotifyTotalCount(_fixture('public_playlist_meta.html')),
        122,
      );
    });

    test('si no hay meta, lee totalCount del initialState en base64', () {
      expect(
        parseSpotifyTotalCount(_fixture('public_playlist_initial_state.html')),
        122,
      );
    });

    test('null si la página no dice el total', () {
      expect(parseSpotifyTotalCount('<html><head></head></html>'), isNull);
      expect(
        parseSpotifyTotalCount(
          '<script id="initialState" type="text/plain">%%%</script>',
        ),
        isNull,
      );
    });
  });
}

String _embed(Map<String, Object?> entity) {
  final json = jsonEncode({
    'props': {
      'pageProps': {
        'state': {
          'data': {'entity': entity},
        },
      },
    },
  });
  return '<html><body><script id="__NEXT_DATA__" type="application/json">'
      '$json</script></body></html>';
}
