import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_song_repository.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/player/domain/usecases/playback_guard.dart';

/// Añade la canción al final de la cola, después de guardarla. Un fallo al
/// guardar se devuelve y no se toca la cola.
final class AddToQueueUseCase {
  const AddToQueueUseCase(this._songs, this._audio);

  final ISongRepository _songs;
  final AudioPlayerService _audio;

  Future<Result<Unit>> call(Song song) async {
    switch (await _songs.save(song)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final saved):
        return guardPlayback(
          () => _audio.addToQueue(saved),
          'No se pudo añadir la canción a la cola',
        );
    }
  }
}
