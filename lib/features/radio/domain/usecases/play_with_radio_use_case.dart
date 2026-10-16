import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/player/domain/usecases/play_queue_use_case.dart';
import 'package:sponify/features/player/domain/usecases/playback_guard.dart';
import 'package:sponify/features/radio/domain/radio_service.dart';

/// Al tocar un resultado de búsqueda: suena esa canción sola y, detrás, la
/// radio (canciones parecidas según los gustos del usuario).
///
/// Con la radio desactivada se mantiene lo de antes: la cola es la lista de
/// resultados empezando en la tocada.
final class PlayWithRadioUseCase {
  const PlayWithRadioUseCase(this._songs, this._audio, this._radio);

  final ISongRepository _songs;
  final AudioPlayerService _audio;
  final RadioService _radio;

  /// Devuelve el resultado de empezar a reproducir. La radio se pide a la
  /// vez que arranca la canción y se añade a la cola cuando llega; el
  /// `Future` termina entonces.
  Future<Result<Unit>> call(List<Song> results, int index) async {
    if (!await _radio.isEnabled()) {
      return PlayQueueUseCase(_songs, _audio)(results, index);
    }
    final Song seed;
    switch (await _songs.save(results[index])) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        seed = value;
    }
    final radio = _radio.forSeed(seed);
    final started = await guardPlayback(
      () => _audio.playQueue([seed]),
      'No se pudo reproducir la canción',
    );
    final next = await radio;
    if (started is Err) return started;
    // Si mientras tanto se puso otra cosa, la radio ya no toca.
    if (_audio.current.queue.firstOrNull?.id != seed.id) return started;
    for (final song in next) {
      final added = await guardPlayback(
        () => _audio.addToQueue(song),
        'No se pudo añadir la radio a la cola',
      );
      // La canción ya suena; sin radio, la cola simplemente se acaba.
      if (added is Err) break;
    }
    return started;
  }
}
