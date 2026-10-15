import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/audio/playback_source_resolver_impl.dart';
import 'package:sponify/core/audio/stream_url_provider.dart';
import 'package:sponify/core/models/song.dart';

class _FakeYoutube implements StreamUrlProvider {
  int calls = 0;
  Object? error;

  @override
  SongSource get source => SongSource.youtube;

  @override
  Future<Uri> fetchStreamUrl(String sourceId) async {
    calls++;
    if (error != null) throw error!;
    return Uri.parse('https://fresh.example/$sourceId?n=$calls');
  }
}

Song _song({String? localPath, String? streamUrl}) => Song(
  id: '1',
  title: 'T',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'abc',
  localPath: localPath,
  streamUrl: streamUrl,
);

void main() {
  final now = DateTime(2026, 10, 11, 12);
  late _FakeYoutube yt;
  late List<Song> missing;
  late Set<String> existingFiles;
  late DefaultPlaybackSourceResolver resolver;

  setUp(() {
    yt = _FakeYoutube();
    missing = [];
    existingFiles = {};
    resolver = DefaultPlaybackSourceResolver(
      providers: [yt],
      onLocalFileMissing: (s) async => missing.add(s),
      fileProbe: (path) async => existingFiles.contains(path),
      clock: () => now,
    );
  });

  String expiresIn(Duration d) =>
      'https://cached.example/a?expire=${now.add(d).millisecondsSinceEpoch ~/ 1000}';

  test('archivo local existente -> LocalFileSource sin tocar la red', () async {
    existingFiles.add('/music/1.m4a');
    final src = await resolver.resolve(_song(localPath: '/music/1.m4a'));
    expect(src, isA<LocalFileSource>());
    expect((src as LocalFileSource).filePath, '/music/1.m4a');
    expect(yt.calls, 0);
  });

  test('archivo borrado -> avisa y cae a streaming', () async {
    final src = await resolver.resolve(_song(localPath: '/music/gone.m4a'));
    expect(src, isA<RemoteStreamSource>());
    expect(missing, hasLength(1));
    expect(yt.calls, 1);
  });

  test('URL cacheada vigente -> se reutiliza', () async {
    final url = expiresIn(const Duration(hours: 3));
    final src = await resolver.resolve(_song(streamUrl: url));
    expect((src as RemoteStreamSource).uri.toString(), url);
    expect(yt.calls, 0);
  });

  test('URL a punto de caducar -> se pide una nueva', () async {
    final url = expiresIn(const Duration(minutes: 2));
    final src = await resolver.resolve(_song(streamUrl: url));
    expect((src as RemoteStreamSource).uri.host, 'fresh.example');
    expect(yt.calls, 1);
  });

  test('la URL nueva queda en caché; forceRefresh la ignora', () async {
    await resolver.resolve(_song());
    await resolver.resolve(_song());
    expect(yt.calls, 1);
    await resolver.resolve(_song(), forceRefresh: true);
    expect(yt.calls, 2);
  });

  test('sin archivo y sin red -> SongUnavailableException', () async {
    yt.error = const SocketException('offline');
    expect(
      () => resolver.resolve(_song()),
      throwsA(isA<SongUnavailableException>()),
    );
  });

  test('YouTube bloqueado -> propaga YoutubeBlockedException', () async {
    yt.error = const YoutubeBlockedException();
    await expectLater(
      resolver.resolve(_song()),
      throwsA(isA<YoutubeBlockedException>()),
    );
  });
}
