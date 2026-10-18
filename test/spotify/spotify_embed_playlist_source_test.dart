import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/data/spotify_embed_playlist_source.dart';
import 'package:sponify/features/playlists/domain/remote_playlist.dart';

String _fixture(String name) =>
    File('test/fixtures/spotify/$name').readAsStringSync();

/// Respuesta programada: un código HTTP con cuerpo, o una excepción de red.
typedef _Reply = ({int status, String body, DioExceptionType? error});

_Reply _ok(String body) => (status: 200, body: body, error: null);
_Reply _status(int code) => (status: code, body: '', error: null);
_Reply _fail(DioExceptionType type) => (status: 0, body: '', error: type);

/// Adaptador HTTP falso: responde por URL con la cola de respuestas dada y
/// guarda las peticiones.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  final Map<String, List<_Reply>> replies;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queue = replies[options.uri.toString()];
    if (queue == null || queue.isEmpty) {
      throw StateError('Petición inesperada: ${options.uri}');
    }
    final reply = queue.length == 1 ? queue.first : queue.removeAt(0);
    if (reply.error case final type?) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _id = '3IH9vnqULmvIUyXAzlL9zl';
const _embedUrl = 'https://open.spotify.com/embed/playlist/$_id';
const _pageUrl = 'https://open.spotify.com/playlist/$_id';

void main() {
  late _FakeAdapter adapter;

  SpotifyEmbedPlaylistSource source(Map<String, List<_Reply>> replies) {
    adapter = _FakeAdapter(replies);
    final dio = Dio()..httpClientAdapter = adapter;
    return SpotifyEmbedPlaylistSource(dio, retryDelay: Duration.zero);
  }

  RemotePlaylist ok(Result<RemotePlaylist> r) {
    expect(r, isA<Ok<RemotePlaylist>>(), reason: '$r');
    return (r as Ok<RemotePlaylist>).value;
  }

  test('lee las pistas del embed y el total de la página pública', () async {
    final s = source({
      _embedUrl: [_ok(_fixture('embed_playlist.html'))],
      _pageUrl: [_ok(_fixture('public_playlist_meta.html'))],
    });

    final playlist = ok(await s.fetch(_id));

    expect(playlist.name, '15 Marzo');
    expect(playlist.tracks, hasLength(3));
    expect(playlist.totalCount, 122);
    final embedUa = adapter.requests.first.headers['User-Agent'] as String;
    final pageUa = adapter.requests.last.headers['User-Agent'] as String;
    expect(embedUa, contains('Chrome/'));
    expect(pageUa, startsWith('facebookexternalhit/'));
  });

  test('reintenta el embed tras un 504 y un timeout', () async {
    final s = source({
      _embedUrl: [
        _status(504),
        _fail(DioExceptionType.receiveTimeout),
        _ok(_fixture('embed_playlist.html')),
      ],
      _pageUrl: [_ok(_fixture('public_playlist_meta.html'))],
    });

    final playlist = ok(await s.fetch(_id));

    expect(playlist.tracks, hasLength(3));
    expect(
      adapter.requests.where((r) => r.uri.toString() == _embedUrl),
      hasLength(3),
    );
  });

  test('si falla la página pública, el total queda en null', () async {
    final s = source({
      _embedUrl: [_ok(_fixture('embed_playlist.html'))],
      _pageUrl: [_status(500)],
    });

    final playlist = ok(await s.fetch(_id));

    expect(playlist.tracks, hasLength(3));
    expect(playlist.totalCount, isNull);
  });

  test('si la página pública no tiene el total, queda en null', () async {
    final s = source({
      _embedUrl: [_ok(_fixture('embed_playlist.html'))],
      _pageUrl: [_ok('<html></html>')],
    });

    expect(ok(await s.fetch(_id)).totalCount, isNull);
  });

  test('un 404 es NotFoundFailure y no se reintenta', () async {
    final s = source({
      _embedUrl: [_status(404)],
    });

    final result = await s.fetch(_id);

    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(adapter.requests, hasLength(1));
  });

  test('tras 3 intentos fallidos da NetworkFailure', () async {
    final s = source({
      _embedUrl: [_fail(DioExceptionType.connectionTimeout)],
    });

    final result = await s.fetch(_id);

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(adapter.requests, hasLength(SpotifyEmbedPlaylistSource.maxAttempts));
  });

  test('si Spotify cambia la página da NetworkFailure', () async {
    final s = source({
      _embedUrl: [_ok('<html>${jsonEncode('otra cosa')}</html>')],
    });

    final result = await s.fetch(_id);

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(adapter.requests, hasLength(1));
  });
}
