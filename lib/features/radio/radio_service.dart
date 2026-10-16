import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/domain/entities/song.dart';
import '../../core/domain/repositories/i_song_repository.dart';
import '../../core/error/result.dart';
import '../../core/settings/settings_dao.dart';
import '../search/data/youtube_search_source.dart';

/// Busca canciones relacionadas con [seed] (sin guardar todavía).
typedef RelatedSongsFetcher = Future<List<Song>> Function(Song seed);

/// Radio automática: cuando la cola termina, propone canciones
/// relacionadas con la última para seguir sonando.
class RadioService {
  RadioService({
    required this.fetchRelated,
    required this.songRepository,
    required this.settings,
  });

  /// Versión real: relacionadas de YouTube (solo metadatos, sin streams).
  RadioService.youtube(
    YoutubeExplode yt, {
    required ISongRepository songRepository,
    required SettingsDao settings,
  }) : this(
         fetchRelated: (seed) => _youtubeRelated(yt, seed),
         songRepository: songRepository,
         settings: settings,
       );

  /// Máximo de canciones que se añaden cada vez que se acaba la cola.
  static const maxSongs = 10;

  final RelatedSongsFetcher fetchRelated;
  final ISongRepository songRepository;
  final SettingsDao settings;

  /// Canciones para continuar tras [queue]; vacío si no hay radio.
  /// Nunca lanza: un fallo (incluido un `Err` al guardar) no debe romper la
  /// reproducción.
  Future<List<Song>> nextFor(List<Song> queue) async {
    try {
      if (queue.isEmpty) return const [];
      final seed = queue.last;
      if (seed.source != SongSource.youtube) return const [];
      final enabled = await settings.getBool(
        SettingsKeys.radioEnabled,
        fallback: true,
      );
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

  static Future<List<Song>> _youtubeRelated(
    YoutubeExplode yt,
    Song seed,
  ) async {
    final video = await yt.videos.get(seed.sourceId);
    final related = await yt.videos.getRelatedVideos(video);
    if (related == null) return const [];
    return related
        .map(YoutubeSearchSource.songFromVideo)
        .whereType<Song>()
        .toList();
  }
}
