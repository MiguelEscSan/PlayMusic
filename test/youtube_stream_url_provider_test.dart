import 'package:flutter_test/flutter_test.dart';
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
}
