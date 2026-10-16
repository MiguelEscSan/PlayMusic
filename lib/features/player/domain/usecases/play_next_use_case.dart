import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';

/// Pone la canción justo después de la actual, después de guardarla. Un
/// fallo al guardar se devuelve y no se toca la cola.
final class PlayNextUseCase {
  const PlayNextUseCase(this._songs, this._audio);

  final ISongRepository _songs;
  final AudioPlayerService _audio;

  Future<Result<Unit>> call(Song song) async {
    switch (await _songs.save(song)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final saved):
        return guardPlayback(
          () => _audio.playNext(saved),
          'No se pudo añadir la canción a continuación',
        );
    }
  }
}
