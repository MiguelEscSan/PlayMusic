import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../../search/data/youtube_search_source.dart';
import '../domain/radio_service.dart';
import 'youtube_related_songs.dart';

/// Candidatas que se leen del Mix; luego se ordenan por gustos y se quedan
/// [RadioService.maxSongs].
const _mixLimit = 40;

/// [RelatedSongsFetcher] real: el Mix de YouTube de la semilla (la lista
/// automática `RD<id>`, más musical que las relacionadas). Si el Mix falla
/// o viene vacío, usa las relacionadas del vídeo.
RelatedSongsFetcher youtubeMixSongs(YoutubeExplode yt) {
  final related = youtubeRelatedSongs(yt);
  return (seed) async {
    try {
      final mix = await yt.playlists
          .getVideos(PlaylistId('RD${seed.sourceId}'))
          .take(_mixLimit)
          .map(YoutubeSearchSource.songFromVideo)
          .where((s) => s != null && s.sourceId != seed.sourceId)
          .cast<Song>()
          .toList()
          .timeout(const Duration(seconds: 15));
      if (mix.isNotEmpty) return mix;
    } catch (_) {
      // Sin Mix: se prueba con las relacionadas.
    }
    return related(seed);
  };
}
