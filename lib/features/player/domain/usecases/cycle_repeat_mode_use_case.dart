import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/player_rules.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Pasa al modo de repetición que sigue al de [snapshot]
/// (ver [nextRepeatMode]).
final class CycleRepeatModeUseCase {
  const CycleRepeatModeUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(PlayerSnapshot snapshot) => guardPlayback(
    () => _audio.setRepeat(nextRepeatMode(snapshot.repeatMode)),
    'No se pudo cambiar el modo de repetición',
  );
}
