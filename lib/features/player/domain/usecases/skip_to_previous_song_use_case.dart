import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/player_rules.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Deslizar hacia atrás: va siempre a la canción anterior de la cola de
/// [snapshot] (sin reiniciar la actual, a diferencia de ⏮). Sin anterior,
/// no hace nada.
final class SkipToPreviousSongUseCase {
  const SkipToPreviousSongUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(PlayerSnapshot snapshot) async {
    final index = previousSongIndex(snapshot);
    if (index == null) return const Ok(unit);
    return guardPlayback(
      () => _audio.skipToIndex(index),
      'No se pudo volver a la canción anterior',
    );
  }
}
