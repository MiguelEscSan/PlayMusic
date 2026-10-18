import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/features/playlists/domain/spotify_playlist_link.dart';

const _id = '3IH9vnqULmvIUyXAzlL9zl';

void main() {
  group('parseSpotifyPlaylistId', () {
    test('acepta el enlace copiado con si, utm_source y pi', () {
      expect(
        parseSpotifyPlaylistId(
          'https://open.spotify.com/playlist/$_id'
          '?si=ldGskkVKRIKNydPEYSkMBA&utm_source=copy-link&pi=5XDsOpGYQwSnk',
        ),
        _id,
      );
    });

    test('acepta variantes del enlace web', () {
      for (final link in [
        'https://open.spotify.com/playlist/$_id',
        'open.spotify.com/playlist/$_id/',
        'https://open.spotify.com/intl-es/playlist/$_id?si=x',
        'https://open.spotify.com/embed/playlist/$_id',
        'http://play.spotify.com/playlist/$_id#arriba',
        '  https://open.spotify.com/playlist/$_id  ',
      ]) {
        expect(parseSpotifyPlaylistId(link), _id, reason: link);
      }
    });

    test('acepta la URI spotify:playlist: y el id solo', () {
      expect(parseSpotifyPlaylistId('spotify:playlist:$_id'), _id);
      expect(parseSpotifyPlaylistId(_id), _id);
    });

    test('rechaza lo que no es una playlist de Spotify', () {
      for (final link in [
        '',
        'hola',
        'https://open.spotify.com/album/$_id',
        'https://open.spotify.com/track/$_id',
        'spotify:album:$_id',
        'https://open.spotify.com/playlist/corto',
        'https://example.com/playlist/$_id',
        'https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H',
        '${_id}x',
      ]) {
        expect(parseSpotifyPlaylistId(link), isNull, reason: link);
      }
    });
  });

  group('isSpotifyLink', () {
    test('reconoce enlaces de Spotify aunque no sean de playlist', () {
      expect(isSpotifyLink('https://open.spotify.com/playlist/$_id'), isTrue);
      expect(isSpotifyLink('https://open.spotify.com/album/$_id'), isTrue);
      expect(isSpotifyLink('spotify:playlist:$_id'), isTrue);
      expect(isSpotifyLink(_id), isTrue);
    });

    test('no confunde enlaces ni ids de YouTube', () {
      expect(
        isSpotifyLink(
          'https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H',
        ),
        isFalse,
      );
      expect(isSpotifyLink('PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H'), isFalse);
      expect(isSpotifyLink('hola'), isFalse);
    });
  });
}
