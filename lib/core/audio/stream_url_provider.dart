import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

/// Obtiene una URL de streaming fresca a partir del id de la canción en su
/// origen. Hay una implementación por cada [SongSource] que la necesite.
abstract interface class StreamUrlProvider {
  SongSource get source;

  Future<Uri> fetchStreamUrl(String sourceId);
}

/// URLs de audio de YouTube mediante youtube_explode_dart.
///
/// Elige el stream de solo audio en contenedor MP4 (AAC/m4a) con más
/// bitrate: es el único formato que reproducen tanto ExoPlayer (Android)
/// como AVPlayer (iOS). WebM/Opus solo se usa si no hay MP4.
class YoutubeStreamUrlProvider implements StreamUrlProvider {
  YoutubeStreamUrlProvider(this._yt);

  final YoutubeExplode _yt;

  @override
  SongSource get source => SongSource.youtube;

  @override
  Future<Uri> fetchStreamUrl(String sourceId) async {
    final manifest = await _yt.videos.streams.getManifest(sourceId);
    final audio = manifest.audioOnly;
    if (audio.isEmpty) {
      throw StateError('YouTube no devolvió streams de audio para $sourceId');
    }
    final mp4 = audio.where((s) => s.container == StreamContainer.mp4);
    final best = mp4.isNotEmpty
        ? mp4.withHighestBitrate()
        : audio.withHighestBitrate();
    return best.url;
  }
}
