import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Pasa a la siguiente canción de la cola.
final class SkipToNextUseCase {
  const SkipToNextUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call() => guardPlayback(
    _audio.skipToNext,
    'No se pudo pasar a la siguiente canción',
  );
}
