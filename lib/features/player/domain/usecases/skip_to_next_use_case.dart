import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Pasa a la siguiente canción de la cola.
final class SkipToNextUseCase {
  const SkipToNextUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call() => guardPlayback(
    _audio.skipToNext,
    'No se pudo pasar a la siguiente canción',
  );
}
