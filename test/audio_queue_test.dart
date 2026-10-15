import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/audio/sponify_audio_handler.dart';
import 'package:sponify/core/models/song.dart';

/// just_audio sin plataforma: registra lo que se carga y permite simular el
/// final de una canción.
class FakePlayer implements AudioPlayer {
  final processing = StreamController<ProcessingState>.broadcast();
  final loaded = <String?>[];
  bool _playing = false;
  ProcessingState _state = ProcessingState.idle;

  void complete() {
    _state = ProcessingState.completed;
    processing.add(ProcessingState.completed);
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => processing.stream;
  @override
  Stream<PlayerException> get errorStream => const Stream.empty();
  @override
  bool get playing => _playing;
  @override
  ProcessingState get processingState => _state;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  double get speed => 1;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loaded.add((source as IndexedAudioSource).tag as String?);
    _state = ProcessingState.ready;
    return null;
  }

  @override
  Future<void> play() async => _playing = true;
  @override
  Future<void> pause() async => _playing = false;
  @override
  Future<void> stop() async {
    _playing = false;
    _state = ProcessingState.idle;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> dispose() async => processing.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalResolver implements PlaybackSourceResolver {
  @override
  Future<PlaybackSource> resolve(
    Song song, {
    bool forceRefresh = false,
  }) async => LocalFileSource('/music/${song.id}.m4a');
}

Song song(String id) => Song(
  id: id,
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$id',
);

void main() {
  late FakePlayer player;
  late SponifyAudioHandler audio;

  setUp(() {
    player = FakePlayer();
    audio = SponifyAudioHandler(resolver: _LocalResolver(), player: player);
  });

  tearDown(() => audio.dispose());

  List<String> ids() => [for (final s in audio.current.queue) s.id];
  String? currentId() => audio.current.currentSong?.id;

  test('playQueue carga la canción pedida y conserva el orden', () async {
    await audio.playQueue([song('a'), song('b'), song('c')], startIndex: 1);
    expect(ids(), ['a', 'b', 'c']);
    expect(currentId(), 'b');
    expect(player.loaded, ['b']);
  });

  test('playNext inserta justo después de la actual', () async {
    await audio.playQueue([song('a'), song('b'), song('c')]);
    await audio.playNext(song('x'));
    expect(ids(), ['a', 'x', 'b', 'c']);
    expect(currentId(), 'a', reason: 'no interrumpe la que suena');
  });

  test('addToQueue añade al final', () async {
    await audio.playQueue([song('a'), song('b')]);
    await audio.addToQueue(song('x'));
    expect(ids(), ['a', 'b', 'x']);
    expect(currentId(), 'a');
  });

  test('con la cola vacía, playNext y addToQueue empiezan a sonar', () async {
    await audio.addToQueue(song('x'));
    expect(currentId(), 'x');
    expect(player.loaded, ['x']);
  });

  test(
    'quitar una anterior a la actual mantiene la canción que suena',
    () async {
      await audio.playQueue([song('a'), song('b'), song('c')], startIndex: 2);
      await audio.removeFromQueue(0);
      expect(ids(), ['b', 'c']);
      expect(currentId(), 'c');
    },
  );

  test('quitar la que suena pasa a la que ocupa su lugar', () async {
    await audio.playQueue([song('a'), song('b'), song('c')]);
    await audio.removeFromQueue(0);
    expect(currentId(), 'b');
    expect(player.loaded.last, 'b');
  });

  test('mover canciones sigue apuntando a la que suena', () async {
    await audio.playQueue([song('a'), song('b'), song('c')], startIndex: 1);
    await audio.moveInQueue(1, 2);
    expect(ids(), ['a', 'c', 'b']);
    expect(currentId(), 'b');
    expect(audio.current.currentIndex, 2);
  });

  test(
    'aleatorio deja la actual primera y al quitarlo vuelve el orden',
    () async {
      final songs = [for (final c in 'abcdefgh'.split('')) song(c)];
      await audio.playQueue(songs, startIndex: 3);

      await audio.setShuffle(true);
      expect(ids().first, 'd');
      expect(ids().toSet(), songs.map((s) => s.id).toSet());

      await audio.setShuffle(false);
      expect(ids(), 'abcdefgh'.split(''));
      expect(currentId(), 'd');
    },
  );

  test('al acabar una canción suena la siguiente', () async {
    await audio.playQueue([song('a'), song('b')]);
    player.complete();
    await pumpEventQueue();
    expect(currentId(), 'b');
    expect(player.loaded, ['a', 'b']);
  });

  group('ganchos', () {
    test('songStarted emite cada canción que empieza a sonar', () async {
      final started = <String>[];
      final sub = audio.songStarted.listen((s) => started.add(s.id));

      await audio.playQueue([song('a'), song('b')]);
      player.complete();
      await pumpEventQueue();

      expect(started, ['a', 'b']);
      await sub.cancel();
    });

    test('onQueueEnded añade lo que devuelve y sigue sonando', () async {
      List<String>? seen;
      audio.onQueueEnded = (queue) async {
        seen = [for (final s in queue) s.id];
        return [song('r1'), song('r2')];
      };

      await audio.playQueue([song('a')]);
      player.complete();
      await pumpEventQueue();

      expect(seen, ['a']);
      expect(ids(), ['a', 'r1', 'r2']);
      expect(currentId(), 'r1');
    });

    test('sin onQueueEnded la cola se para al final', () async {
      await audio.playQueue([song('a')]);
      player.complete();
      await pumpEventQueue();

      expect(ids(), ['a']);
      expect(player.playing, isFalse);
    });

    test('stopAfterCurrent para al acabar la canción y se desactiva', () async {
      await audio.playQueue([song('a'), song('b')]);
      await audio.setStopAfterCurrent(true);
      expect(audio.current.stopAfterCurrent, isTrue);

      player.complete();
      await pumpEventQueue();

      expect(currentId(), 'a', reason: 'no avanza');
      expect(player.playing, isFalse);
      expect(player.loaded, ['a']);
      expect(audio.current.stopAfterCurrent, isFalse);
    });
  });
}
