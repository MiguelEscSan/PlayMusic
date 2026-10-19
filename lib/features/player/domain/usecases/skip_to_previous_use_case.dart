import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Botón ⏮: vuelve a la anterior o, pasados unos segundos, reinicia la
/// actual (lo decide el reproductor).
final class SkipToPreviousUseCase {
  const SkipToPreviousUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call() => guardPlayback(
    _audio.skipToPrevious,
    'No se pudo volver a la canción anterior',
  );
}
