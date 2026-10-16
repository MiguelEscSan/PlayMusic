import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Mueve la reproducción a [position] de la canción actual.
final class SeekUseCase {
  const SeekUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(Duration position) => guardPlayback(
    () => _audio.seek(position),
    'No se pudo cambiar la posición',
  );
}
