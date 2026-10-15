// StreamAudioSource lleva años marcado como experimental en just_audio, pero
// es la vía oficial para servirle bytes propios al reproductor.
// ignore_for_file: experimental_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Fuente de streaming cuyos bytes descarga Dart (dart:io) en vez de la pila
/// HTTP de ExoPlayer; just_audio se los pasa al reproductor por su proxy
/// local.
///
/// googlevideo responde 403 a las peticiones que hace ExoPlayer en Android
/// para URLs que sí acepta desde dart:io (el mismo cliente HTTP con el que
/// youtube_explode_dart obtuvo el manifest), así que pedimos los rangos
/// nosotros.
class HttpRangeAudioSource extends StreamAudioSource {
  HttpRangeAudioSource(this.uri, {this.headers = const {}, super.tag});

  final Uri uri;
  final Map<String, String> headers;

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final request = await _client.getUrl(uri);
    headers.forEach(request.headers.set);
    // `end` es exclusivo en just_audio e inclusivo en HTTP.
    request.headers.set(
      HttpHeaders.rangeHeader,
      'bytes=$from-${end == null ? '' : end - 1}',
    );
    final response = await request.close();

    if (response.statusCode != HttpStatus.partialContent &&
        response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      debugPrint(
        'HttpRangeAudioSource: HTTP ${response.statusCode} '
        '(c=${uri.queryParameters['c']}, itag=${uri.queryParameters['itag']})',
      );
      throw HttpStatusException(response.statusCode, uri: uri);
    }

    final partial = response.statusCode == HttpStatus.partialContent;
    return StreamAudioResponse(
      sourceLength: partial
          ? _totalFromContentRange(response.headers)
          : _nullIfNegative(response.contentLength),
      contentLength: _nullIfNegative(response.contentLength),
      offset: partial ? from : 0,
      contentType: response.headers.contentType?.mimeType ?? 'audio/mp4',
      stream: response,
    );
  }

  /// `Content-Range: bytes 0-1023/3449447` -> 3449447.
  static int? _totalFromContentRange(HttpHeaders headers) {
    final value = headers.value(HttpHeaders.contentRangeHeader);
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    return slash < 0 ? null : int.tryParse(value.substring(slash + 1));
  }

  static int? _nullIfNegative(int length) => length < 0 ? null : length;
}

/// Respuesta HTTP de error de googlevideo, con su código para que quien la
/// reciba distinga un bloqueo (403) de otros fallos sin comparar textos.
class HttpStatusException extends HttpException {
  HttpStatusException(this.statusCode, {super.uri}) : super('HTTP $statusCode');

  final int statusCode;
}
