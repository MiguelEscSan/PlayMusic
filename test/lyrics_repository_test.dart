import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/features/lyrics/data/lyrics_repository.dart';
import 'package:koda/features/lyrics/domain/lyrics.dart';

/// Adaptador HTTP falso: responde según la ruta y registra cada petición.
/// Nunca toca la red.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _song = Song(
  id: '1',
  title: 'Canción',
  artist: 'Artista',
  durationMs: 200000,
  source: SongSource.youtube,
  sourceId: 'abc',
);

void main() {
  late _FakeAdapter adapter;
  late LyricsRepositoryImpl repo;

  void setUpWith(ResponseBody Function(RequestOptions) handler) {
    adapter = _FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    repo = LyricsRepositoryImpl(dio: dio);
  }

  test('get con letra sincronizada devuelve SyncedLyrics', () async {
    setUpWith(
      (_) => _json({
        'instrumental': false,
        'plainLyrics': 'Hola\nAdiós',
        'syncedLyrics': '[00:01.00]Hola\n[00:02.00]Adiós',
      }),
    );

    final lyrics = (await repo.getLyrics(
      _song.title,
      _song.artist,
      durationSeconds: _song.duration.inSeconds,
    )).valueOrNull;

    expect(lyrics, isA<SyncedLyrics>());
    expect((lyrics as SyncedLyrics).lines, const [
      LyricLine(Duration(seconds: 1), 'Hola'),
      LyricLine(Duration(seconds: 2), 'Adiós'),
    ]);
    final req = adapter.requests.single;
    expect(req.uri.path, '/api/get');
    expect(req.uri.queryParameters, {
      'track_name': 'Canción',
      'artist_name': 'Artista',
      'duration': '200',
    });
    expect(req.headers['User-Agent'], contains('Koda'));
  });

  test('get solo con texto plano devuelve PlainLyrics', () async {
    setUpWith(
      (_) => _json({'plainLyrics': 'Solo texto', 'syncedLyrics': null}),
    );
    final lyrics = (await repo.getLyrics(
      _song.title,
      _song.artist,
      durationSeconds: _song.duration.inSeconds,
    )).valueOrNull;
    expect(lyrics, isA<PlainLyrics>());
    expect((lyrics as PlainLyrics).text, 'Solo texto');
  });

  test('instrumental devuelve InstrumentalLyrics', () async {
    setUpWith((_) => _json({'instrumental': true}));
    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).valueOrNull,
      isA<InstrumentalLyrics>(),
    );
  });

  test('404 en get → search elige la duración más cercana', () async {
    setUpWith((o) {
      if (o.uri.path == '/api/get') return _json({'code': 404}, 404);
      return _json([
        {'duration': 230, 'plainLyrics': 'lejana'},
        {'duration': 203, 'plainLyrics': 'cercana'},
        {'duration': 196, 'plainLyrics': 'algo menos cercana'},
      ]);
    });

    final lyrics = (await repo.getLyrics(
      _song.title,
      _song.artist,
      durationSeconds: _song.duration.inSeconds,
    )).valueOrNull;

    expect((lyrics as PlainLyrics).text, 'cercana');
    expect(adapter.requests.map((r) => r.uri.path), [
      '/api/get',
      '/api/search',
    ]);
    expect(adapter.requests.last.uri.queryParameters, {
      'track_name': 'Canción',
      'artist_name': 'Artista',
    });
  });

  test('search sin coincidencias dentro de ±5 s → notFound', () async {
    setUpWith((o) {
      if (o.uri.path == '/api/get') return _json({'code': 404}, 404);
      return _json([
        {'duration': 230, 'plainLyrics': 'lejana'},
      ]);
    });
    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).valueOrNull,
      isA<LyricsNotFound>(),
    );
  });

  test('nada en get ni en search → notFound', () async {
    setUpWith((o) {
      if (o.uri.path == '/api/get') return _json({'code': 404}, 404);
      return _json(<Object>[]);
    });
    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).valueOrNull,
      isA<LyricsNotFound>(),
    );
  });

  test('la caché evita una segunda petición para la misma canción', () async {
    setUpWith((_) => _json({'plainLyrics': 'x'}));
    await repo.getLyrics(
      _song.title,
      _song.artist,
      durationSeconds: _song.duration.inSeconds,
    );
    await repo.getLyrics(
      _song.title,
      _song.artist,
      durationSeconds: _song.duration.inSeconds,
    );
    expect(adapter.requests, hasLength(1));
  });

  test('error de red → NetworkFailure y no se cachea', () async {
    var fail = true;
    setUpWith((o) {
      if (fail) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'sin red',
        );
      }
      return _json({'plainLyrics': 'ok'});
    });

    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).failureOrNull,
      isA<NetworkFailure>(),
    );

    fail = false;
    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).valueOrNull,
      isA<PlainLyrics>(),
    );
  });

  test('error 500 → NetworkFailure', () async {
    setUpWith((_) => _json({'error': 'boom'}, 500));
    expect(
      (await repo.getLyrics(
        _song.title,
        _song.artist,
        durationSeconds: _song.duration.inSeconds,
      )).failureOrNull,
      isA<NetworkFailure>(),
    );
  });
}
