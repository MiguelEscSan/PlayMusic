import 'dart:async';

import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/domain/entities/song.dart';

/// Reproductor falso: registra cada llamada en [calls] (en orden) y, si
/// [error] no es null, las acciones lo lanzan después de registrarse.
class FakeAudioPlayerService implements AudioPlayerService {
  final snapshotController = StreamController<PlayerSnapshot>.broadcast();
  final positionController = StreamController<Duration>.broadcast();

  Object? error;
  PlayerSnapshot snapshot = const PlayerSnapshot();
  final List<String> calls = [];

  /// Registro compartido opcional para comprobar el orden respecto a otras
  /// dependencias (p. ej. el repositorio de canciones).
  List<String>? log;

  Future<void> _record(String call) async {
    calls.add(call);
    log?.add('audio.$call');
    if (error case final e?) throw e;
  }

  @override
  Stream<PlayerSnapshot> get snapshots => snapshotController.stream;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  PlayerSnapshot get current => snapshot;

  @override
  Future<void> playSong(Song song) => _record('playSong(${song.sourceId})');

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) => _record(
    'playQueue([${songs.map((s) => s.id).join(',')}], $startIndex)',
  );

  @override
  Future<void> addToQueue(Song song) => _record('addToQueue(${song.id})');

  @override
  Future<void> playNext(Song song) => _record('playNext(${song.id})');

  @override
  Future<void> removeFromQueue(int index) => _record('removeFromQueue($index)');

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) =>
      _record('moveInQueue($oldIndex, $newIndex)');

  @override
  Future<void> play() => _record('play');

  @override
  Future<void> pause() => _record('pause');

  @override
  Future<void> togglePlayPause() => _record('togglePlayPause');

  @override
  Future<void> stop() => _record('stop');

  @override
  Future<void> seek(Duration position) =>
      _record('seek(${position.inMilliseconds})');

  @override
  Future<void> skipToNext() => _record('skipToNext');

  @override
  Future<void> skipToPrevious() => _record('skipToPrevious');

  @override
  Future<void> skipToIndex(int index) => _record('skipToIndex($index)');

  @override
  Future<void> setRepeat(PlayerRepeatMode mode) =>
      _record('setRepeat(${mode.name})');

  @override
  Future<void> setShuffle(bool enabled) => _record('setShuffle($enabled)');

  @override
  Future<void> setStopAfterCurrent(bool enabled) =>
      _record('setStopAfterCurrent($enabled)');

  @override
  Future<void> onSongStorageChanged(Song updated) =>
      _record('onSongStorageChanged(${updated.id})');

  @override
  Stream<Song> get songStarted => const Stream.empty();

  @override
  QueueEndedCallback? onQueueEnded;

  @override
  Future<void> dispose() async {
    await snapshotController.close();
    await positionController.close();
  }
}
