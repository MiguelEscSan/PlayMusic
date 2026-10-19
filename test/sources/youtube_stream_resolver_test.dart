import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/playback_source.dart';
import 'package:koda/sources/youtube/youtube_stream_resolver.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  final visionOsUrl = Uri.parse('https://example.com/visionos');
  final defaultUrl = Uri.parse('https://example.com/default');

  test('usa primero el cliente visionOS', () async {
    final calls = <List<YoutubeApiClient>?>[];
    final provider = YoutubeStreamResolver.withLoader((id, clients) async {
      calls.add(clients);
      return visionOsUrl;
    });

    final url = await provider.fetchStreamUrl('abc');

    expect(url, visionOsUrl);
    expect(calls, hasLength(1));
    expect(calls.single, [YoutubeStreamResolver.visionOs]);
  });

  test('si visionOS falla cae a los clientes por defecto', () async {
    final calls = <List<YoutubeApiClient>?>[];
    final provider = YoutubeStreamResolver.withLoader((id, clients) async {
      calls.add(clients);
      if (clients != null) throw Exception('visionOS caído');
      return defaultUrl;
    });

    final url = await provider.fetchStreamUrl('abc');

    expect(url, defaultUrl);
    expect(calls, [
      [YoutubeStreamResolver.visionOs],
      null,
    ]);
  });

  test('si visionOS no da audio cae a los clientes por defecto', () async {
    final provider = YoutubeStreamResolver.withLoader(
      (id, clients) async => clients != null ? null : defaultUrl,
    );

    expect(await provider.fetchStreamUrl('abc'), defaultUrl);
  });

  test('si ningún cliente da audio lanza StateError', () async {
    final provider = YoutubeStreamResolver.withLoader(
      (id, clients) async => null,
    );

    expect(provider.fetchStreamUrl('abc'), throwsStateError);
  });

  test('si todos los clientes fallan propaga el último error', () async {
    final provider = YoutubeStreamResolver.withLoader(
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
      final provider = YoutubeStreamResolver.withLoader(
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
      'si ningún cliente pasa la sonda lanza SourceBlockedException',
      () async {
        final provider = YoutubeStreamResolver.withLoader(
          (id, clients) async => clients != null ? bigVision : bigDefault,
          probe: (url) async => false,
        );

        await expectLater(
          provider.fetchStreamUrl('abc'),
          throwsA(
            isA<SourceBlockedException>().having(
              (e) => e.message,
              'message',
              SourceBlockedException.defaultMessage,
            ),
          ),
        );
      },
    );

    test(
      'bloqueado en un cliente y error en otro sigue siendo bloqueo',
      () async {
        final provider = YoutubeStreamResolver.withLoader((id, clients) async {
          if (clients == null) throw Exception('defaults caídos');
          return bigVision;
        }, probe: (url) async => false);

        await expectLater(
          provider.fetchStreamUrl('abc'),
          throwsA(isA<SourceBlockedException>()),
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
      final smallProvider = YoutubeStreamResolver.withLoader(
        (id, clients) async => small,
        probe: probe,
      );
      expect(await smallProvider.fetchStreamUrl('abc'), small);

      final unknownProvider = YoutubeStreamResolver.withLoader(
        (id, clients) async => visionOsUrl,
        probe: probe,
      );
      expect(await unknownProvider.fetchStreamUrl('abc'), visionOsUrl);

      expect(probes, 0);
    });

    test('si la sonda falla por red no bloquea la canción', () async {
      final provider = YoutubeStreamResolver.withLoader(
        (id, clients) async => bigVision,
        probe: (url) async => throw const SocketException('timeout'),
      );

      expect(await provider.fetchStreamUrl('abc'), bigVision);
    });

    test('pide un byte pasado el límite: min(clen - 1, 2 MB)', () {
      expect(YoutubeStreamResolver.probeOffset(bigVision), 2 * 1024 * 1024);
      final justAbove = Uri.parse('https://e.com/a?clen=1600000');
      expect(YoutubeStreamResolver.probeOffset(justAbove), 1599999);
      expect(YoutubeStreamResolver.probeOffset(visionOsUrl), isNull);
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

      expect(await YoutubeStreamResolver.httpRangeProbe(at('/ok')), isTrue);
      expect(
        await YoutubeStreamResolver.httpRangeProbe(at('/blocked')),
        isFalse,
      );
      expect(ranges.first, 'bytes=2097152-2097152');
    });
  });

  group('límite de peticiones de YouTube', () {
    test('solo descarga la página del vídeo si falta el visitorData', () async {
      final requested = <bool>[];
      final load = YoutubeStreamResolver.manifestLoader((
        id,
        clients, {
        required bool requireWatchPage,
      }) async {
        requested.add(requireWatchPage);
        throw Exception('sin red');
      });
      final withVisitor = YoutubeStreamResolver.withVisitorData(
        YoutubeStreamResolver.visionOs,
        'VD',
      );

      for (final clients in [
        [withVisitor],
        [YoutubeStreamResolver.visionOs],
        null,
      ]) {
        await expectLater(load('abc', clients), throwsException);
      }

      expect(requested, [false, true, false]);
    });

    test('withVisitorData lo pone en el contexto y en la cabecera', () {
      final client = YoutubeStreamResolver.withVisitorData(
        YoutubeStreamResolver.visionOs,
        'VD',
      );

      expect(client.payload['context']['client']['visitorData'], 'VD');
      expect(client.payload['context']['client']['clientName'], 'VISIONOS');
      expect(client.headers['X-Goog-Visitor-Id'], 'VD');
      expect(client.headers['X-YouTube-Client-Name'], '101');
      expect(client.apiUrl, YoutubeStreamResolver.visionOs.apiUrl);
    });

    test('pide el visitorData una vez y lo reutiliza', () async {
      var visitorCalls = 0;
      final sent = <String?>[];
      final provider = YoutubeStreamResolver.withLoader(
        (id, clients) async {
          sent.add(clients?.single.payload['context']['client']['visitorData']);
          return visionOsUrl;
        },
        visitorData: () async {
          visitorCalls++;
          return 'VD';
        },
      );

      await provider.fetchStreamUrl('a');
      await provider.fetchStreamUrl('b');

      expect(visitorCalls, 1);
      expect(sent, ['VD', 'VD']);
    });

    test(
      'si visionOS falla, la próxima canción pide otro visitorData',
      () async {
        var visitorCalls = 0;
        final provider = YoutubeStreamResolver.withLoader((id, clients) async {
          if (clients != null && id == 'a') throw Exception('unplayable');
          return clients != null ? visionOsUrl : defaultUrl;
        }, visitorData: () async => 'VD${++visitorCalls}');

        expect(await provider.fetchStreamUrl('a'), defaultUrl);
        expect(await provider.fetchStreamUrl('b'), visionOsUrl);
        expect(visitorCalls, 2);
      },
    );

    test('sin visitorData usa el cliente tal cual', () async {
      final calls = <List<YoutubeApiClient>?>[];
      final provider = YoutubeStreamResolver.withLoader((id, clients) async {
        calls.add(clients);
        return visionOsUrl;
      }, visitorData: () async => null);

      await provider.fetchStreamUrl('a');

      expect(calls.single, [YoutubeStreamResolver.visionOs]);
    });

    test('al primer límite para y no prueba más clientes', () async {
      var calls = 0;
      final provider = YoutubeStreamResolver.withLoader((id, clients) async {
        calls++;
        throw RequestLimitExceededException('429');
      });

      await expectLater(
        provider.fetchStreamUrl('abc'),
        throwsA(
          isA<SourceRateLimitedException>().having(
            (e) => e.message,
            'message',
            SourceRateLimitedException.rateLimitedMessage,
          ),
        ),
      );
      expect(calls, 1);
    });

    test('durante el enfriamiento falla sin pedir nada a YouTube', () async {
      var now = DateTime(2026, 10, 17, 12);
      var limited = true;
      var calls = 0;
      final provider = YoutubeStreamResolver.withLoader((id, clients) async {
        calls++;
        if (limited) throw RequestLimitExceededException('429');
        return visionOsUrl;
      }, clock: () => now);

      await expectLater(
        provider.fetchStreamUrl('a'),
        throwsA(isA<SourceRateLimitedException>()),
      );
      limited = false;
      now = now.add(const Duration(minutes: 1));
      await expectLater(
        provider.fetchStreamUrl('b'),
        throwsA(isA<SourceRateLimitedException>()),
      );
      expect(calls, 1, reason: 'no vuelve a llamar a YouTube');

      now = now.add(YoutubeStreamResolver.rateLimitCooldown);
      expect(await provider.fetchStreamUrl('c'), visionOsUrl);
      expect(calls, 2);
    });
  });
}
