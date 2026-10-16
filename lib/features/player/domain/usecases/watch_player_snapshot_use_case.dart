import 'package:sponify/core/audio/audio_player_service.dart';

/// Estado completo del reproductor; emite en cada cambio relevante.
final class WatchPlayerSnapshotUseCase {
  const WatchPlayerSnapshotUseCase(this._audio);

  final AudioPlayerService _audio;

  Stream<PlayerSnapshot> call() => _audio.snapshots;
}
