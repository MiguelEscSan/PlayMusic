import 'package:koda/core/audio/audio_player_service.dart';

/// Posición de la canción actual, con alta frecuencia (barra de progreso).
final class WatchPlayerPositionUseCase {
  const WatchPlayerPositionUseCase(this._audio);

  final AudioPlayerService _audio;

  Stream<Duration> call() => _audio.positionStream;
}
