import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Invierte el modo aleatorio respecto al que tiene [snapshot].
final class ToggleShuffleUseCase {
  const ToggleShuffleUseCase(this._audio);

  final AudioPlayerService _audio;

  Future<Result<Unit>> call(PlayerSnapshot snapshot) => guardPlayback(
    () => _audio.setShuffle(!snapshot.shuffleEnabled),
    'No se pudo cambiar el modo aleatorio',
  );
}
