import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Activa o desactiva "parar al terminar la canción actual" (temporizador
/// de apagado "al terminar la canción").
final class SetStopAfterCurrentUseCase {
  const SetStopAfterCurrentUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(bool enabled) => guardPlayback(
    () => _audio.setStopAfterCurrent(enabled),
    'No se pudo programar la parada al final de la canción',
  );
}
