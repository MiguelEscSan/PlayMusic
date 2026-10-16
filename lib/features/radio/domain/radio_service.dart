import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/history/domain/i_history_repository.dart';
import 'package:sponify/features/radio/domain/taste_ranker.dart';

/// Busca canciones parecidas a [seed] (sin guardar todavía). Puede lanzar
/// si falla la red. La versión real (Mix de YouTube, con las relacionadas
/// de respaldo) vive en `radio/data/youtube_mix_songs.dart`.
typedef RelatedSongsFetcher = Future<List<Song>> Function(Song seed);

/// Radio: canciones parecidas a una semilla, ordenadas según los gustos
/// del usuario ("me gusta" e historial) y sin repetir las recientes.
///
/// Se usa al tocar una canción de la búsqueda ([forSeed]) y cuando se
/// acaba la cola ([nextFor], que `bootstrap()` engancha a `onQueueEnded`).
class RadioService {
  RadioService({
    required this.fetchRelated,
    required this.songRepository,
    required this.settings,
    this.history,
  });

  /// Máximo de canciones que se añaden cada vez.
  static const maxSongs = 10;

  final RelatedSongsFetcher fetchRelated;
  final ISongRepository songRepository;
  final ISettingsRepository settings;

  /// Sin historial solo cuentan los "me gusta".
  final IHistoryRepository? history;

  /// true si la radio está activada; false también si no se puede leer el
  /// ajuste.
  Future<bool> isEnabled() async =>
      (await settings.getRadioEnabled()).valueOrNull ?? false;

  /// Canciones para continuar tras [queue] (semilla: la última); vacío si
  /// no hay radio.
  Future<List<Song>> nextFor(List<Song> queue) async {
    if (queue.isEmpty) return const [];
    return _pick(queue.last, exclude: queue);
  }

  /// Canciones para seguir después de [seed], que acaba de empezar a sonar.
  Future<List<Song>> forSeed(Song seed) => _pick(seed, exclude: [seed]);

  /// Nunca lanza: un fallo (incluido un `Err` al leer el ajuste o al
  /// guardar) no debe romper la reproducción.
  Future<List<Song>> _pick(Song seed, {required List<Song> exclude}) async {
    try {
      if (seed.source != SongSource.youtube) return const [];
      // Desactivada, o sin poder leer el ajuste: no se añade nada.
      if (!await isEnabled()) return const [];

      final seen = {for (final s in exclude) TasteProfile.songKey(s)};
      final candidates = [
        for (final song in await fetchRelated(seed))
          if (seen.add(TasteProfile.songKey(song))) song,
      ];
      final ranked = rankByTaste(candidates, await _taste());

      final picked = <Song>[];
      for (final song in ranked.take(maxSongs)) {
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

  /// Un fallo al leer gustos o historial solo hace que no cuenten.
  Future<TasteProfile> _taste() async {
    final history = this.history;
    return TasteProfile(
      liked: (await songRepository.getLiked()).valueOrNull ?? const [],
      top: (await history?.topSongs())?.valueOrNull ?? const [],
      recent: (await history?.recentSongs())?.valueOrNull ?? const [],
    );
  }
}
