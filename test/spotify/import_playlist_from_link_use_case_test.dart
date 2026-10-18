import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/domain/i_playlist_importer.dart';
import 'package:sponify/features/playlists/domain/usecases/import_playlist_from_link_use_case.dart';

import '../domain/fakes/fake_services.dart';

void main() {
  late FakePlaylistImporter youtube;
  late FakePlaylistImporter spotify;
  late ImportPlaylistFromLinkUseCase import;

  setUp(() {
    youtube = FakePlaylistImporter();
    spotify = FakePlaylistImporter();
    import = ImportPlaylistFromLinkUseCase(youtube: youtube, spotify: spotify);
  });

  test('un enlace de Spotify va al importador de Spotify', () async {
    const link = 'https://open.spotify.com/playlist/3IH9vnqULmvIUyXAzlL9zl';
    spotify.progress = const [(0, 2), (2, 2)];
    final progress = <(int, int)>[];

    final result = await import(
      link,
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(result.isOk, isTrue);
    expect(spotify.calls, [link]);
    expect(youtube.calls, isEmpty);
    expect(progress, [(0, 2), (2, 2)]);
    expect(import.sourceOf(link), PlaylistLinkSource.spotify);
  });

  test(
    'cualquier otro texto va al importador de YouTube, como antes',
    () async {
      const link = 'https://www.youtube.com/playlist?list=PLabc';
      await import(link);
      await import('basura');

      expect(youtube.calls, [link, 'basura']);
      expect(spotify.calls, isEmpty);
      expect(import.sourceOf(link), PlaylistLinkSource.youtube);
    },
  );

  test('una excepción del importador es NetworkFailure', () async {
    spotify.error = Exception('sin red');
    final result = await import('spotify:playlist:3IH9vnqULmvIUyXAzlL9zl');
    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('un fallo tipado llega tal cual', () async {
    youtube.result = const Err(InvalidPlaylistLinkFailure());
    expect(
      (await import('x')).failureOrNull,
      isA<InvalidPlaylistLinkFailure>(),
    );
  });
}
