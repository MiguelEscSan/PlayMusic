import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/http_range_audio_source.dart';

void main() {
  late HttpServer server;
  late Uri uri;
  final body = List<int>.generate(1000, (i) => i % 256);
  final seenHeaders = <String, String?>{};
  var status = HttpStatus.partialContent;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    uri = Uri.parse('http://127.0.0.1:${server.port}/audio?c=ANDROID&itag=140');
    server.listen((req) async {
      seenHeaders['range'] = req.headers.value(HttpHeaders.rangeHeader);
      seenHeaders['ua'] = req.headers.value(HttpHeaders.userAgentHeader);
      final res = req.response..statusCode = status;
      if (status == HttpStatus.partialContent) {
        final m = RegExp(r'bytes=(\d+)-(\d*)')
            .firstMatch(seenHeaders['range']!)!;
        final from = int.parse(m[1]!);
        final to = m[2]!.isEmpty ? body.length - 1 : int.parse(m[2]!);
        res.headers
          ..contentType = ContentType('audio', 'mp4')
          ..set(
            HttpHeaders.contentRangeHeader,
            'bytes $from-$to/${body.length}',
          );
        res.contentLength = to - from + 1;
        res.add(body.sublist(from, to + 1));
      }
      await res.close();
    });
  });

  tearDown(() async {
    status = HttpStatus.partialContent;
    await server.close(force: true);
  });

  test(
    'pide el rango con end exclusivo y devuelve offset y tamaño total',
    () async {
      final source = HttpRangeAudioSource(uri, headers: {'User-Agent': 'x'});
      final res = await source.request(100, 200);
      final bytes = await res.stream.expand((c) => c).toList();

      expect(seenHeaders['range'], 'bytes=100-199');
      expect(seenHeaders['ua'], 'x');
      expect(res.offset, 100);
      expect(res.sourceLength, 1000);
      expect(res.contentLength, 100);
      expect(res.contentType, 'audio/mp4');
      expect(bytes, body.sublist(100, 200));
    },
  );

  test('sin start ni end pide desde el principio hasta el final', () async {
    final res = await HttpRangeAudioSource(uri).request();
    await res.stream.drain<void>();
    expect(seenHeaders['range'], 'bytes=0-');
    expect(res.sourceLength, 1000);
  });

  test(
    'un 403 se convierte en error para que el reproductor reintente',
    () async {
      status = HttpStatus.forbidden;
      expect(
        HttpRangeAudioSource(uri).request(0, 10),
        throwsA(
          isA<HttpStatusException>().having(
            (e) => e.statusCode,
            'statusCode',
            HttpStatus.forbidden,
          ),
        ),
      );
    },
  );
}
