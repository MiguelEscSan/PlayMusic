import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../../search/data/youtube_search_source.dart';
import '../domain/radio_service.dart';

/// [RelatedSongsFetcher] real: relacionadas de YouTube (solo metadatos,
/// sin streams).
RelatedSongsFetcher youtubeRelatedSongs(YoutubeExplode yt) => (seed) async {
  final video = await yt.videos.get(seed.sourceId);
  final related = await yt.videos.getRelatedVideos(video);
  if (related == null) return const [];
  return related
      .map(YoutubeSearchSource.songFromVideo)
      .whereType<Song>()
      .toList();
};
