import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/features/playlists/data/track_match_scoring.dart';
import 'package:koda/features/playlists/domain/remote_playlist.dart';

const _dardos = RemoteTrack(
  title: 'Dardos',
  artists: ['Romeo Santos', 'Prince Royce'],
  durationMs: 243070,
);

MatchCandidate _c(
  String title, {
  String channel = 'Romeo Santos',
  int seconds = 243,
  bool isLive = false,
  String id = 'v',
}) => MatchCandidate(
  title: title,
  channel: channel,
  duration: Duration(seconds: seconds),
  isLive: isLive,
  song: Song(
    id: '',
    title: title,
    artist: channel,
    durationMs: seconds * 1000,
    source: SongSource.youtube,
    sourceId: id,
  ),
);

void main() {
  group('matchQuery', () {
    test('usa el artista principal y el título', () {
      expect(matchQuery(_dardos), 'Romeo Santos Dardos');
    });

    test('sin artistas, solo el título', () {
      expect(
        matchQuery(const RemoteTrack(title: 'X', artists: [], durationMs: 1)),
        'X',
      );
    });
  });

  group('scoreCandidate', () {
    test('acepta la versión exacta y la puntúa alto', () {
      final score = scoreCandidate(
        _dardos,
        _c('Romeo Santos, Prince Royce - Dardos (Official Video)'),
      );
      expect(score, isNotNull);
      expect(score!, greaterThan(0.8));
    });

    test('rechaza si la duración se va más de 30 s', () {
      expect(
        scoreCandidate(_dardos, _c('Romeo Santos - Dardos', seconds: 280)),
        isNull,
      );
    });

    test('penaliza una diferencia de 10 a 30 s frente a una exacta', () {
      final exact = scoreCandidate(_dardos, _c('Romeo Santos - Dardos'));
      final off = scoreCandidate(
        _dardos,
        _c('Romeo Santos - Dardos', seconds: 263),
      );
      expect(off, isNotNull);
      expect(off!, lessThan(exact!));
    });

    test('rechaza directos si el título de Spotify no lo es', () {
      expect(
        scoreCandidate(_dardos, _c('Romeo Santos - Dardos (En Vivo)')),
        isNull,
      );
      expect(scoreCandidate(_dardos, _c('Dardos', isLive: true)), isNull);
    });

    test('acepta un directo si la pista de Spotify es en directo', () {
      const live = RemoteTrack(
        title: 'Dardos - Live',
        artists: ['Romeo Santos'],
        durationMs: 243000,
      );
      expect(
        scoreCandidate(live, _c('Romeo Santos - Dardos (Live)')),
        isNotNull,
      );
    });

    test('rechaza covers, karaokes y versiones aceleradas', () {
      for (final title in [
        'Dardos - Romeo Santos (Cover)',
        'Dardos Karaoke - Romeo Santos',
        'Romeo Santos - Dardos (sped up)',
        'Romeo Santos te enseña a tocar Dardos en piano',
        'Dardos - Spotify Sessions',
      ]) {
        expect(scoreCandidate(_dardos, _c(title)), isNull, reason: title);
      }
    });

    test('rechaza si el título no se parece', () {
      expect(
        scoreCandidate(_dardos, _c('Romeo Santos - Propuesta Indecente')),
        isNull,
      );
    });

    test('rechaza si no aparece ningún artista', () {
      expect(
        scoreCandidate(_dardos, _c('Dardos', channel: 'Canal Cualquiera')),
        isNull,
      );
    });

    test('ignora tildes, mayúsculas y el "feat." de Spotify', () {
      const track = RemoteTrack(
        title: 'Canción Bonita (feat. Ricky Martin)',
        artists: ['Carlos Vives'],
        durationMs: 200000,
      );
      final candidate = _c(
        'CARLOS VIVES - CANCION BONITA',
        channel: 'Carlos Vives',
        seconds: 200,
      );
      expect(scoreCandidate(track, candidate), isNotNull);
    });

    test('quita sufijos de Spotify como "- Remastered 2011"', () {
      const track = RemoteTrack(
        title: 'Moves Like Jagger - Studio Recording From The Voice',
        artists: ['Maroon 5', 'Christina Aguilera'],
        durationMs: 202640,
      );
      expect(
        scoreCandidate(
          track,
          _c('Moves Like Jagger', channel: 'Maroon 5 - Topic', seconds: 202),
        ),
        isNotNull,
      );
    });
  });

  group('pickBestMatch', () {
    test('prefiere el canal Topic oficial a un canal de letras', () {
      final lyrics = _c(
        'Romeo Santos, Prince Royce - Dardos (Letra/Lyrics)',
        channel: 'Letras Latinas',
        id: 'lyrics',
      );
      final topic = _c('Dardos', channel: 'Romeo Santos - Topic', id: 'topic');
      expect(pickBestMatch(_dardos, [lyrics, topic]), same(topic));
    });

    test('prefiere la duración más cercana', () {
      final far = _c('Romeo Santos - Dardos', seconds: 262, id: 'far');
      final near = _c('Romeo Santos - Dardos', seconds: 244, id: 'near');
      expect(pickBestMatch(_dardos, [far, near]), same(near));
    });

    test('null si ninguno es aceptable', () {
      expect(
        pickBestMatch(_dardos, [
          _c('Romeo Santos - Dardos (En Vivo)'),
          _c('Otra canción', channel: 'Otro'),
        ]),
        isNull,
      );
      expect(pickBestMatch(_dardos, const []), isNull);
    });
  });
}
