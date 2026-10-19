import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Mueve la canción de [oldIndex] a [newIndex] dentro de la cola.
final class MoveInQueueUseCase {
  const MoveInQueueUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(int oldIndex, int newIndex) => guardPlayback(
    () => _audio.moveInQueue(oldIndex, newIndex),
    'No se pudo reordenar la cola',
  );
}
