import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/radio/domain/radio_service.dart';
import 'package:sponify/features/radio/domain/usecases/play_with_radio_use_case.dart';

import 'fakes/fake_audio_player_service.dart';
import 'fakes/fake_feature_repositories.dart';
import 'fakes/fake_song_repository.dart';

Song _song(String id) => Song(
  id: id,
  title: 'T$id',
  artist: 'A$id',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Como el fake normal, pero la cola de [current] sigue a `playQueue`.
class _QueueAudio extends FakeAudioPlayerService {
  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    await super.playQueue(songs, startIndex: startIndex);
    snapshot = PlayerSnapshot(queue: songs, currentIndex: startIndex);
  }
}

void main() {
  late _QueueAudio audio;
  late FakeSongRepository songs;
  late FakeSettingsRepository settings;

  setUp(() {
    audio = _QueueAudio();
    songs = FakeSongRepository()
      ..saveResult = null
      ..getLikedResult = const Ok([]);
    settings = FakeSettingsRepository();
  });

  PlayWithRadioUseCase useCase(Future<List<Song>> Function(Song) fetch) =>
      PlayWithRadioUseCase(
        songs,
        audio,
        RadioService(
          fetchRelated: fetch,
          songRepository: songs,
          settings: settings,
          history: FakeHistoryRepository(),
        ),
      );

  final results = [_song('a'), _song('b'), _song('c')];

  test('suena la tocada sola y detrás la radio, no los resultados', () async {
    Song? seed;
    final result = await useCase((s) async {
      seed = s;
      return [_song('r1'), _song('b'), _song('r2')];
    })(results, 1);

    expect(result, const Ok(unit));
    expect(seed?.sourceId, 'b');
    expect(audio.calls, [
      'playQueue([b], 0)',
      'addToQueue(r1)',
      'addToQueue(r2)',
    ]);
  });

  test('con la radio desactivada, la cola son los resultados', () async {
    settings.radioEnabled = false;
    await useCase((_) async => [_song('r1')])(results, 1);
    expect(audio.calls, ['playQueue([a,b,c], 1)']);
  });

  test(
    'si mientras llega la radio se pone otra canción, no la añade',
    () async {
      await useCase((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        audio.snapshot = PlayerSnapshot(queue: [_song('z')], currentIndex: 0);
        return [_song('r1')];
      })(results, 0);
      expect(audio.calls, ['playQueue([a], 0)']);
    },
  );

  test('sin red suena igual la canción', () async {
    final result = await useCase((_) async => throw Exception('sin red'))(
      results,
      2,
    );
    expect(result, const Ok(unit));
    expect(audio.calls, ['playQueue([c], 0)']);
  });
}
