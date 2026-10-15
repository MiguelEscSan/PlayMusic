import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/audio/stream_url_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  final visionOsUrl = Uri.parse('https://example.com/visionos');
  final defaultUrl = Uri.parse('https://example.com/default');

  test('usa primero el cliente visionOS', () async {
    final calls = <List<YoutubeApiClient>?>[];
    final provider = YoutubeStreamUrlProvider.withLoader((id, clients) async {
      calls.add(clients);
      return visionOsUrl;
    });

    final url = await provider.fetchStreamUrl('abc');

    expect(url, visionOsUrl);
    expect(calls, hasLength(1));
    expect(calls.single, [YoutubeStreamUrlProvider.visionOs]);
  });

  test('si visionOS falla cae a los clientes por defecto', () async {
    final calls = <List<YoutubeApiClient>?>[];
    final provider = YoutubeStreamUrlProvider.withLoader((id, clients) async {
      calls.add(clients);
      if (clients != null) throw Exception('visionOS caído');
      return defaultUrl;
    });

    final url = await provider.fetchStreamUrl('abc');

    expect(url, defaultUrl);
    expect(calls, [
      [YoutubeStreamUrlProvider.visionOs],
      null,
    ]);
  });

  test('si visionOS no da audio cae a los clientes por defecto', () async {
    final provider = YoutubeStreamUrlProvider.withLoader(
      (id, clients) async => clients != null ? null : defaultUrl,
    );

    expect(await provider.fetchStreamUrl('abc'), defaultUrl);
  });

  test('si ningún cliente da audio lanza StateError', () async {
    final provider = YoutubeStreamUrlProvider.withLoader(
      (id, clients) async => null,
    );

    expect(provider.fetchStreamUrl('abc'), throwsStateError);
  });

  test('si todos los clientes fallan propaga el último error', () async {
    final provider = YoutubeStreamUrlProvider.withLoader(
      (id, clients) async => throw const SocketException('offline'),
    );

    await expectLater(
      provider.fetchStreamUrl('abc'),
      throwsA(isA<SocketException>()),
    );
  });

  group('sonda contra el límite de ~1 MB', () {
    // clen de 4 MB: por encima del umbral, hay que comprobar la URL.
    final bigVision = Uri.parse('https://example.com/visionos?clen=4000000');
    final bigDefault = Uri.parse('https://example.com/default?clen=4000000');

    test('si visionOS no pasa la sonda prueba el siguiente cliente', () async {
      final probed = <Uri>[];
      final provider = YoutubeStreamUrlProvider.withLoader(
        (id, clients) async => clients != null ? bigVision : bigDefault,
        probe: (url) async {
          probed.add(url);
          return url == bigDefault;
        },
      );

      expect(await provider.fetchStreamUrl('abc'), bigDefault);
      expect(probed, [bigVision, bigDefault]);
    });

    test(
      'si ningún cliente pasa la sonda lanza YoutubeBlockedException',
      () async {
        final provider = YoutubeStreamUrlProvider.withLoader(
          (id, clients) async => clients != null ? bigVision : bigDefault,
          probe: (url) async => false,
        );

        await expectLater(
          provider.fetchStreamUrl('abc'),
          throwsA(
            isA<YoutubeBlockedException>().having(
              (e) => e.message,
              'message',
              YoutubeBlockedException.defaultMessage,
            ),
          ),
        );
      },
    );

    test(
      'bloqueado en un cliente y error en otro sigue siendo bloqueo',
      () async {
        final provider = YoutubeStreamUrlProvider.withLoader((
          id,
          clients,
        ) async {
          if (clients == null) throw Exception('defaults caídos');
          return bigVision;
        }, probe: (url) async => false);

        await expectLater(
          provider.fetchStreamUrl('abc'),
          throwsA(isA<YoutubeBlockedException>()),
        );
      },
    );

    test('no sondea si clen falta o es pequeño', () async {
      var probes = 0;
      Future<bool> probe(Uri url) async {
        probes++;
        return false;
      }

      final small = Uri.parse('https://example.com/visionos?clen=1000000');
      final smallProvider = YoutubeStreamUrlProvider.withLoader(
        (id, clients) async => small,
        probe: probe,
      );
      expect(await smallProvider.fetchStreamUrl('abc'), small);

      final unknownProvider = YoutubeStreamUrlProvider.withLoader(
        (id, clients) async => visionOsUrl,
        probe: probe,
      );
      expect(await unknownProvider.fetchStreamUrl('abc'), visionOsUrl);

      expect(probes, 0);
    });

    test('si la sonda falla por red no bloquea la canción', () async {
      final provider = YoutubeStreamUrlProvider.withLoader(
        (id, clients) async => bigVision,
        probe: (url) async => throw const SocketException('timeout'),
      );

      expect(await provider.fetchStreamUrl('abc'), bigVision);
    });

    test('pide un byte pasado el límite: min(clen - 1, 2 MB)', () {
      expect(YoutubeStreamUrlProvider.probeOffset(bigVision), 2 * 1024 * 1024);
      final justAbove = Uri.parse('https://e.com/a?clen=1600000');
      expect(YoutubeStreamUrlProvider.probeOffset(justAbove), 1599999);
      expect(YoutubeStreamUrlProvider.probeOffset(visionOsUrl), isNull);
    });

    test('la sonda HTTP acepta 206 y rechaza 403', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ranges = <String?>[];
      server.listen((req) {
        ranges.add(req.headers.value(HttpHeaders.rangeHeader));
        req.response.statusCode = req.uri.path == '/ok'
            ? HttpStatus.partialContent
            : HttpStatus.forbidden;
        req.response.close();
      });
      addTearDown(server.close);

      Uri at(String path) =>
          Uri.parse('http://127.0.0.1:${server.port}$path?clen=4000000');

      expect(await YoutubeStreamUrlProvider.httpRangeProbe(at('/ok')), isTrue);
      expect(
        await YoutubeStreamUrlProvider.httpRangeProbe(at('/blocked')),
        isFalse,
      );
      expect(ranges.first, 'bytes=2097152-2097152');
    });
  });
}
