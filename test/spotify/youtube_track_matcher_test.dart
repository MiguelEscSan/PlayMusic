import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/data/track_match_scoring.dart';
import 'package:sponify/features/playlists/data/youtube_track_matcher.dart';
import 'package:sponify/features/playlists/domain/remote_playlist.dart';

const _track = RemoteTrack(
  title: 'I Wanna Be Yours',
  artists: ['Arctic Monkeys'],
  durationMs: 183956,
);

MatchCandidate _candidate(String title, String channel, int seconds) =>
    MatchCandidate(
      title: title,
      channel: channel,
      duration: Duration(seconds: seconds),
      isLive: false,
      song: Song(
        id: '',
        title: title,
        artist: channel,
        durationMs: seconds * 1000,
        source: SongSource.youtube,
        sourceId: 'yt-$seconds',
      ),
    );

void main() {
  test('busca "artista título" y devuelve la mejor con los datos de '
      'Spotify', () async {
    String? query;
    final matcher = YoutubeTrackMatcher((q) async {
      query = q;
      return [
        _candidate('Arctic Monkeys - I Wanna Be Yours (Live)', 'Fan', 190),
        _candidate('I Wanna Be Yours', 'Arctic Monkeys - Topic', 184),
      ];
    });

    final result = await matcher.match(_track);

    expect(query, 'Arctic Monkeys I Wanna Be Yours');
    final song = result.valueOrNull!;
    expect(song.sourceId, 'yt-184');
    expect(song.source, SongSource.youtube);
    expect(song.title, 'I Wanna Be Yours');
    expect(song.artist, 'Arctic Monkeys');
  });

  test('Ok(null) si ningún resultado es aceptable', () async {
    final matcher = YoutubeTrackMatcher(
      (_) async => [_candidate('Otra cosa', 'Otro canal', 184)],
    );
    expect(await matcher.match(_track), const Ok<Song?>(null));
  });

  test('un fallo de la búsqueda es NetworkFailure', () async {
    final matcher = YoutubeTrackMatcher((_) async => throw Exception('red'));
    final result = await matcher.match(_track);
    expect(result.failureOrNull, isA<NetworkFailure>());
  });
}
