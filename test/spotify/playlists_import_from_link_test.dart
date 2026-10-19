import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/downloads/presentation/downloads_providers.dart';
import 'package:koda/features/playlists/presentation/playlists_providers.dart';

import '../domain/fakes/fake_playlist_repository.dart';
import '../domain/fakes/fake_services.dart';

void main() {
  late FakePlaylistImporter youtube;
  late FakePlaylistImporter spotify;
  late ProviderContainer container;

  setUp(() {
    youtube = FakePlaylistImporter();
    spotify = FakePlaylistImporter();
    container = ProviderContainer.test(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(
          FakePlaylistRepository()..getAllResult = const Ok([]),
        ),
        downloadedKeysProvider.overrideWithValue(const {}),
        youtubePlaylistImporterProvider.overrideWithValue(youtube),
        spotifyPlaylistImporterProvider.overrideWithValue(spotify),
      ],
    );
  });

  test('importFromLink manda los enlaces de Spotify a su importador', () async {
    const link = 'https://open.spotify.com/playlist/3IH9vnqULmvIUyXAzlL9zl';

    final result = await container
        .read(playlistsProvider.notifier)
        .importFromLink(link);

    expect(result.isOk, isTrue);
    expect(spotify.calls, [link]);
    expect(youtube.calls, isEmpty);
  });

  test('importFromLink manda el resto a YouTube', () async {
    const link = 'https://www.youtube.com/playlist?list=PLabc';

    await container.read(playlistsProvider.notifier).importFromLink(link);

    expect(youtube.calls, [link]);
    expect(spotify.calls, isEmpty);
  });
}
