import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Alterna entre reproducir y pausar.
final class TogglePlayPauseUseCase {
  const TogglePlayPauseUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call() =>
      guardPlayback(_audio.togglePlayPause, 'No se pudo reproducir o pausar');
}
