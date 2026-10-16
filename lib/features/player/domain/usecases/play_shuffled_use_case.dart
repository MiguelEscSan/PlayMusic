import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/play_queue_use_case.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Activa el modo aleatorio y reproduce [songs] desde el principio. Una
/// lista vacía no hace nada.
final class PlayShuffledUseCase {
  const PlayShuffledUseCase(this._songs, this._audio);

  final ISongRepository _songs;
  final AudioPlayerService _audio;

  Future<Result<Unit>> call(List<Song> songs) async {
    if (songs.isEmpty) return const Ok(unit);
    final shuffled = await guardPlayback(
      () => _audio.setShuffle(true),
      'No se pudo activar el modo aleatorio',
    );
    if (shuffled case Err(:final failure)) return Err(failure);
    return PlayQueueUseCase(_songs, _audio)(songs, 0);
  }
}
