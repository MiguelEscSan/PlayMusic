import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Pausa la reproducción (p. ej. al acabar el temporizador de apagado).
final class PausePlaybackUseCase {
  const PausePlaybackUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call() =>
      guardPlayback(_audio.pause, 'No se pudo pausar');
}
