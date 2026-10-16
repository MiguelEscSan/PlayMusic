import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Quita de la cola la canción [index].
final class RemoveFromQueueUseCase {
  const RemoveFromQueueUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(int index) => guardPlayback(
    () => _audio.removeFromQueue(index),
    'No se pudo quitar la canción de la cola',
  );
}
