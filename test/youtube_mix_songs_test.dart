import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/features/radio/data/youtube_mix_songs.dart';

/// Respuesta real de `youtubei/v1/next` para el Mix de "Blinding Lights",
/// recortada a 4 entradas y a los campos que se leen.
Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/youtube_mix_next.json').readAsStringSync())
        as Map<String, dynamic>;

List<dynamic> _entries(Map<String, dynamic> json) =>
    json['contents']['twoColumnWatchNextResults']['playlist']['playlist']['contents']
        as List<dynamic>;

Map<String, dynamic> _renderer(Map<String, dynamic> json, int i) =>
    _entries(json)[i]['playlistPanelVideoRenderer'] as Map<String, dynamic>;

void main() {
  test('reads the Mix songs in order, without the seed', () {
    final songs = parseMixSongs(_fixture(), seedId: '4NRXx6U8ABQ');

    expect(songs.map((s) => s.sourceId), [
      'XXYlFuWEuKI',
      '34Na4j8AVgA',
      'yzTuBuRdAyA',
    ]);
    final first = songs.first;
    expect(first.title, 'Save Your Tears');
    expect(first.artist, 'The Weeknd');
    expect(
      first.durationMs,
      const Duration(minutes: 4, seconds: 9).inMilliseconds,
    );
    expect(
      first.artworkUrl,
      'https://i.ytimg.com/vi/XXYlFuWEuKI/hqdefault.jpg',
    );
    expect(songs.last.title, 'The Hills');
  });

  test('skips entries without duration or longer than 20 minutes', () {
    final json = _fixture();
    _renderer(json, 1).remove('lengthText');
    _renderer(json, 2)['lengthText'] = {'simpleText': '1:02:03'};

    final songs = parseMixSongs(json, seedId: '4NRXx6U8ABQ');

    expect(songs.map((s) => s.sourceId), ['yzTuBuRdAyA']);
  });

  test('reads titles split in runs', () {
    final json = _fixture();
    _renderer(json, 1)['title'] = {
      'runs': [
        {'text': 'Save '},
        {'text': 'Your Tears'},
      ],
    };

    final songs = parseMixSongs(json, seedId: '4NRXx6U8ABQ');

    expect(songs.first.title, 'Save Your Tears');
  });

  test('drops the artist prefix of collaborations', () {
    final json = _fixture();
    _renderer(json, 1)['title'] = {
      'simpleText': 'Shakira, Burna Boy - Dai Dai (Official Video)',
    };
    _renderer(json, 1)['longBylineText'] = {
      'runs': [
        {'text': 'Shakira y 2 más'},
      ],
    };

    final song = parseMixSongs(json, seedId: '4NRXx6U8ABQ').first;

    expect(song.title, 'Dai Dai');
    expect(song.artist, 'Shakira');
  });

  test('respects the limit', () {
    final songs = parseMixSongs(_fixture(), seedId: '4NRXx6U8ABQ', limit: 2);

    expect(songs, hasLength(2));
  });

  test('returns nothing when the response has no playlist', () {
    expect(parseMixSongs({'contents': {}}, seedId: 'x'), isEmpty);
  });
}
