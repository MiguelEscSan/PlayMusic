import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';
import 'package:sponify/features/player/domain/usecases/save_songs.dart';

/// Reemplaza la cola por [songs] y empieza en [index]. Primero guarda todas
/// las canciones; si alguna falla, devuelve ese `Err` y no reproduce nada.
final class PlayQueueUseCase {
  const PlayQueueUseCase(this._songs, this._audio);

  final ISongRepository _songs;
  final AudioPlayerService _audio;

  Future<Result<Unit>> call(List<Song> songs, int index) async {
    switch (await saveSongs(_songs, songs)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final saved):
        return guardPlayback(
          () => _audio.playQueue(saved, startIndex: index),
          'No se pudo reproducir la cola',
        );
    }
  }
}
