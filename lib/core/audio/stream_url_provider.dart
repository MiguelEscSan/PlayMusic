import 'dart:io';
import 'dart:math';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';
import 'playback_source.dart';

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

/// Comprueba que [url] se puede leer más allá del primer ~1 MB. Devuelve
/// false si googlevideo la rechaza (403).
typedef StreamUrlProbe = Future<bool> Function(Uri url);

/// URLs de audio de YouTube mediante youtube_explode_dart.
///
/// Para muchos vídeos (sobre todo música) YouTube solo deja leer ~1 MB del
/// archivo si la petición no lleva un PO token (prueba anti-bots de
/// BotGuard); a partir de ahí googlevideo responde 403, tanto al reproducir
/// como al descargar. Los clientes por defecto de youtube_explode_dart caen en
/// ese límite, así que primero se pide el manifest como [visionOs], que hoy no
/// lo exige, y solo si falla se usan los clientes por defecto.
///
/// Plan B por si YouTube restringe también visionOS: antes de devolver una
/// URL se pide un byte pasado ese límite ([httpRangeProbe]); si responde 403
/// se prueba el siguiente cliente de [fallbackClients] y, si ninguno vale, se
/// lanza [YoutubeBlockedException] con un mensaje claro para el usuario.
///
/// Elige el stream de solo audio en contenedor MP4 (AAC/m4a) con más
/// bitrate: ExoPlayer lo reproduce en cualquier versión de Android y el
/// archivo descargado queda como .m4a estándar. WebM/Opus solo se usa si no
/// hay MP4.
class YoutubeStreamUrlProvider implements StreamUrlProvider {
  YoutubeStreamUrlProvider(YoutubeExplode yt, {StreamUrlProbe? probe})
    : _load = _manifestLoader(yt),
      _probe = probe ?? httpRangeProbe;

  YoutubeStreamUrlProvider.withLoader(this._load, {StreamUrlProbe? probe})
    : _probe = probe ?? httpRangeProbe;

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

  /// Clientes a probar, en orden (null = los de youtube_explode_dart). Para
  /// añadir un plan C basta con insertar otro cliente en la lista.
  static const List<List<YoutubeApiClient>?> fallbackClients = [
    [visionOs],
    null,
  ];

  /// Por debajo de este tamaño el archivo cabe (casi) entero en el tramo que
  /// YouTube deja leer sin PO token: comprobarlo no aporta nada.
  static const probeMinBytes = 1536 * 1024;

  /// Byte que se pide en la sonda: bien pasado el límite de ~1 MB.
  static const _probeTargetByte = 2 * 1024 * 1024;

  static final HttpClient _probeClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  final YoutubeAudioUrlLoader _load;
  final StreamUrlProbe _probe;

  @override
  SongSource get source => SongSource.youtube;

  /// Prueba cada cliente de [fallbackClients] y devuelve la primera URL que
  /// pasa la sonda. Si alguna URL existía pero todas daban 403 lanza
  /// [YoutubeBlockedException]; si no, el último error (o [StateError] si
  /// ningún cliente devolvió audio).
  @override
  Future<Uri> fetchStreamUrl(String sourceId) async {
    Object? lastError;
    StackTrace? lastStack;
    var blocked = false;
    for (final clients in fallbackClients) {
      final Uri? url;
      try {
        url = await _load(sourceId, clients);
      } catch (e, st) {
        // Este cliente no sirve para este vídeo: probamos el siguiente.
        lastError = e;
        lastStack = st;
        continue;
      }
      if (url == null) continue;
      if (await _passesProbe(url)) return url;
      blocked = true;
    }
    if (blocked) throw const YoutubeBlockedException();
    if (lastError != null) Error.throwWithStackTrace(lastError, lastStack!);
    throw StateError('YouTube no devolvió streams de audio para $sourceId');
  }

  Future<bool> _passesProbe(Uri url) async {
    if (probeOffset(url) == null) return true;
    try {
      return await _probe(url);
    } catch (_) {
      // Sin respuesta clara (timeout, red): no damos la canción por
      // bloqueada; si de verdad lo está, el reproductor lo detectará.
      return true;
    }
  }

  /// Byte a pedir para comprobar [url], o null si no merece la pena (falta
  /// `clen` o el archivo es menor que [probeMinBytes]).
  static int? probeOffset(Uri url) {
    final clen = int.tryParse(url.queryParameters['clen'] ?? '');
    if (clen == null || clen < probeMinBytes) return null;
    return min(clen - 1, _probeTargetByte);
  }

  /// Sonda real: pide un único byte pasado el límite de ~1 MB y acepta la URL
  /// solo si googlevideo responde 200/206.
  static Future<bool> httpRangeProbe(Uri url) async {
    final offset = probeOffset(url) ?? 0;
    final request = await _probeClient.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-$offset');
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    return response.statusCode == HttpStatus.partialContent ||
        response.statusCode == HttpStatus.ok;
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
