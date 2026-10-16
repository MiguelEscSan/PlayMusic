import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Salta a la canción [index] de la cola.
final class SkipToQueueIndexUseCase {
  const SkipToQueueIndexUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(int index) => guardPlayback(
    () => _audio.skipToIndex(index),
    'No se pudo reproducir esa canción de la cola',
  );
}
