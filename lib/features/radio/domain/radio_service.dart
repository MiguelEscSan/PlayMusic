import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Busca canciones relacionadas con [seed] (sin guardar todavía). Puede
/// lanzar si falla la red. La versión real (YouTube) vive en
/// `radio/data/youtube_related_songs.dart`.
typedef RelatedSongsFetcher = Future<List<Song>> Function(Song seed);

/// Radio automática: cuando la cola termina, propone canciones
/// relacionadas con la última para seguir sonando.
///
/// No tiene botón: `bootstrap()` lo engancha a `onQueueEnded` del
/// reproductor.
class RadioService {
  RadioService({
    required this.fetchRelated,
    required this.songRepository,
    required this.settings,
  });

  /// Máximo de canciones que se añaden cada vez que se acaba la cola.
  static const maxSongs = 10;

  final RelatedSongsFetcher fetchRelated;
  final ISongRepository songRepository;
  final ISettingsRepository settings;

  /// Canciones para continuar tras [queue]; vacío si no hay radio.
  /// Nunca lanza: un fallo (incluido un `Err` al leer el ajuste o al
  /// guardar) no debe romper la reproducción.
  Future<List<Song>> nextFor(List<Song> queue) async {
    try {
      if (queue.isEmpty) return const [];
      final seed = queue.last;
      if (seed.source != SongSource.youtube) return const [];
      // Desactivada, o sin poder leer el ajuste: no se añade nada.
      final enabled = (await settings.getRadioEnabled()).valueOrNull ?? false;
      if (!enabled) return const [];

      final seen = {for (final s in queue) _key(s)};
      final picked = <Song>[];
      for (final song in await fetchRelated(seed)) {
        if (picked.length >= maxSongs) break;
        if (!seen.add(_key(song))) continue;
        // Se guardan antes de entrar en la cola: historial y favoritos
        // necesitan un id real.
        switch (await songRepository.save(song)) {
          case Ok(:final value):
            picked.add(value);
          case Err():
            return const [];
        }
      }
      return picked;
    } catch (_) {
      return const [];
    }
  }

  static String _key(Song s) => '${s.source.name}:${s.sourceId}';
}
