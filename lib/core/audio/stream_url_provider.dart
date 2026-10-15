import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

/// Obtiene una URL de streaming fresca a partir del id de la canción en su
/// origen. Hay una implementación por cada [SongSource] que la necesite.
abstract interface class StreamUrlProvider {
  SongSource get source;

  Future<Uri> fetchStreamUrl(String sourceId);
}

/// Pide a YouTube la URL de audio de [videoId] con [clients] (null = los
/// clientes por defecto de youtube_explode_dart). Devuelve null si no hay
/// streams de audio.
typedef YoutubeAudioUrlLoader = Future<Uri?> Function(
  String videoId,
  List<YoutubeApiClient>? clients,
);

/// URLs de audio de YouTube mediante youtube_explode_dart.
///
/// Para muchos vídeos (sobre todo música) YouTube solo deja leer ~1 MB del
/// archivo si la petición no lleva un PO token (prueba anti-bots de
/// BotGuard); a partir de ahí googlevideo responde 403, tanto al reproducir
/// como al descargar. Los clientes por defecto de youtube_explode_dart caen en
/// ese límite, así que primero se pide el manifest como [visionOs], que hoy no
/// lo exige, y solo si falla se usan los clientes por defecto.
///
/// Elige el stream de solo audio en contenedor MP4 (AAC/m4a) con más
/// bitrate: ExoPlayer lo reproduce en cualquier versión de Android y el
/// archivo descargado queda como .m4a estándar. WebM/Opus solo se usa si no
/// hay MP4.
class YoutubeStreamUrlProvider implements StreamUrlProvider {
  YoutubeStreamUrlProvider(YoutubeExplode yt) : _load = _manifestLoader(yt);

  YoutubeStreamUrlProvider.withLoader(this._load);

  /// Cliente de la app de YouTube para Apple Vision Pro: el que usa yt-dlp
  /// por defecto (2026.08.19) porque YouTube no le exige PO token. Si deja de
  /// funcionar, copiar el siguiente cliente por defecto de yt-dlp
  /// (`_DEFAULT_CLIENTS` en yt_dlp/extractor/youtube/_video.py).
  static const visionOs = YoutubeApiClient(
    {
      'context': {
        'client': {
          'clientName': 'VISIONOS',
          'clientVersion': '1.02',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'userAgent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 '
              'Safari/605.1.15',
          'osName': 'visionOS',
          'osVersion': '26.5.23O471',
          'hl': 'en',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      },
    },
    'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    headers: {
      'X-YouTube-Client-Name': '101',
      'X-YouTube-Client-Version': '1.02',
    },
  );

  final YoutubeAudioUrlLoader _load;

  @override
  SongSource get source => SongSource.youtube;

  @override
  Future<Uri> fetchStreamUrl(String sourceId) async {
    try {
      final url = await _load(sourceId, const [visionOs]);
      if (url != null) return url;
    } catch (_) {
      // visionOS no disponible para este vídeo: probamos los de siempre.
    }
    final url = await _load(sourceId, null);
    if (url == null) {
      throw StateError('YouTube no devolvió streams de audio para $sourceId');
    }
    return url;
  }

  static YoutubeAudioUrlLoader _manifestLoader(YoutubeExplode yt) =>
      (videoId, clients) async {
        final manifest = await yt.videos.streams.getManifest(
          videoId,
          ytClients: clients,
        );
        final audio = manifest.audioOnly;
        if (audio.isEmpty) return null;
        final mp4 = audio.where((s) => s.container == StreamContainer.mp4);
        final best = mp4.isNotEmpty
            ? mp4.withHighestBitrate()
            : audio.withHighestBitrate();
        return best.url;
      };
}
