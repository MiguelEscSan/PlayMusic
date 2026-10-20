import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/domain/entities/last_playback.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/playback/data/last_playback_recorder.dart';

import 'domain/fakes/fake_audio_player_service.dart';
import 'domain/fakes/fake_feature_repositories.dart';
import 'domain/fakes/fake_song_repository.dart';

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Canciones en memoria por id; las que no están devuelven `Err`.
class _SongsById extends FakeSongRepository {
  _SongsById(this.byId);

  final Map<String, Song> byId;

  @override
  Future<Result<Song>> findById(String id) async => switch (byId[id]) {
    final song? => Ok(song),
    null => const Err(UnexpectedFailure('missing in fake')),
  };
}

void main() {
  test('guarda cola, índice y posición al cambiar el estado', () async {
    final audio = FakeAudioPlayerService();
    final settings = FakeSettingsRepository();
    final recorder = LastPlaybackRecorder(audio: audio, settings: settings);
    addTearDown(() async {
      recorder.dispose();
      await audio.dispose();
    });

    audio.positionController.add(const Duration(seconds: 42));
    await Future<void>.delayed(Duration.zero);
    audio.snapshotController.add(
      PlayerSnapshot(
        queue: [_song('a'), _song('b')],
        currentIndex: 1,
        currentSong: _song('b'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(settings.lastPlayback?.songIds, ['a', 'b']);
    expect(settings.lastPlayback?.index, 1);
    expect(settings.lastPlayback?.position, const Duration(seconds: 42));
  });

  test('restaura omitiendo canciones borradas y ajusta el índice', () async {
    final settings = FakeSettingsRepository()
      ..lastPlayback = const LastPlayback(
        songIds: ['a', 'x', 'c'],
        index: 2,
        position: Duration(seconds: 7),
      );
    final songs = _SongsById({'a': _song('a'), 'c': _song('c')});

    List<Song>? restoredSongs;
    int? restoredIndex;
    Duration? restoredPosition;
    await restoreLastPlayback(
      settings: settings,
      songs: songs,
      restore: (list, {required index, required position}) async {
        restoredSongs = list;
        restoredIndex = index;
        restoredPosition = position;
      },
    );

    expect(restoredSongs?.map((s) => s.id), ['a', 'c']);
    expect(restoredIndex, 1);
    expect(restoredPosition, const Duration(seconds: 7));
  });
}
