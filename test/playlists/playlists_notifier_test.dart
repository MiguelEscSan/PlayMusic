import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/data/liked_playlist.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/playlists/data/playlist_cover_service.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/features/playlists/data/youtube_playlist_importer.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_playlist_repository.dart';
import '../helpers/liked_playlist_override.dart';

Song _song(int i) => Song(
  id: '',
  title: 'T$i',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

List<String> _names(List<Playlist> list) => [for (final p in list) p.name];

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songDao;
  late PlaylistDao playlistDao;
  late PlaylistRepositoryImpl repo;
  late FlakyPlaylistRepository flaky;
  late Directory tmp;
  late ProviderContainer container;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    playlistDao = PlaylistDao(db, songDao);
    repo = PlaylistRepositoryImpl(playlistDao);
    flaky = FlakyPlaylistRepository(repo);
    tmp = await Directory.systemTemp.createTemp('sponify_playlists');
    container = ProviderContainer.test(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(flaky),
        playlistCoverServiceProvider.overrideWithValue(
          PlaylistCoverService(flaky, Directory(p.join(tmp.path, 'covers'))),
        ),
        downloadedKeysProvider.overrideWithValue(const {}),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  PlaylistsNotifier notifier() => container.read(playlistsProvider.notifier);

  Future<List<Playlist>> load() {
    container.listen(playlistsProvider, (_, _) {});
    return container.read(playlistsProvider.future);
  }

  Future<List<Playlist>> reloaded() => container.read(playlistsProvider.future);

  group('carga', () {
    test('Ok expone las playlists', () async {
      _ok(await repo.create('A'));
      _ok(await repo.create('B'));
      expect(_names(await load()), unorderedEquals(['A', 'B']));
    });

    test('Err es un AsyncError y reintentar vuelve a cargar', () async {
      _ok(await repo.create('A'));
      flaky.getAllFailures = 1;

      await expectLater(load(), throwsA(same(FlakyPlaylistRepository.failure)));
      expect(container.read(playlistsProvider).isLoading, isFalse);

      container.invalidate(playlistsProvider);
      expect(_names(await reloaded()), ['A']);
    });
  });

  test('create añade la playlist a la lista', () async {
    expect(await load(), isEmpty);
    final created = _ok(await notifier().create('Nueva'));
    expect(created.name, 'Nueva');
    expect(_names(await reloaded()), ['Nueva']);
  });

  test('create con Err lo devuelve', () async {
    final failing = ProviderContainer.test(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(FakePlaylistRepository()),
        downloadedKeysProvider.overrideWithValue(const {}),
      ],
    );
    final result = await failing.read(playlistsProvider.notifier).create('X');
    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });

  test('rename refresca la lista y el detalle', () async {
    final id = _ok(await repo.create('A')).id;
    await load();
    container.listen(playlistProvider(id), (_, _) {});
    await container.read(playlistProvider(id).future);

    _ok(await notifier().rename(id, 'B'));

    expect(_names(await reloaded()), ['B']);
    expect((await container.read(playlistProvider(id).future)).name, 'B');
  });

  test('delete la quita de la lista y el detalle pasa a no existir', () async {
    final id = _ok(await repo.create('A')).id;
    await load();
    container.listen(playlistProvider(id), (_, _) {});
    await container.read(playlistProvider(id).future);

    _ok(await notifier().delete(id));

    expect(await reloaded(), isEmpty);
    await expectLater(
      container.read(playlistProvider(id).future),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('portada: cambiarla y quitarla refresca la lista', () async {
    final id = _ok(await repo.create('A')).id;
    await load();
    final image = File(p.join(tmp.path, 'pic.jpg'))..writeAsStringSync('x');

    _ok(await notifier().setCoverFromFile(id, image.path));
    final withCover = (await reloaded()).single.coverUrl;
    expect(withCover, isNotNull);
    expect(File(withCover!).existsSync(), isTrue);

    _ok(await notifier().clearCover(id));
    expect((await reloaded()).single.coverUrl, isNull);
  });

  test('portada con Err lo devuelve', () async {
    final id = _ok(await repo.create('A')).id;
    await load();
    final image = File(p.join(tmp.path, 'pic.jpg'))..writeAsStringSync('x');
    flaky.setCoverFailures = 1;

    final result = await notifier().setCoverFromFile(id, image.path);

    expect(result.isErr, isTrue);
    expect((await reloaded()).single.coverUrl, isNull);
  });

  group('addSong (hoja "Añadir a una playlist")', () {
    test('Ok(true) la añade y refresca lista y detalle', () async {
      final id = _ok(await repo.create('A')).id;
      await load();
      container.listen(playlistProvider(id), (_, _) {});
      await container.read(playlistProvider(id).future);

      expect(_ok(await notifier().addSong(id, _song(1))), isTrue);

      expect((await reloaded()).single.length, 1);
      expect((await container.read(playlistProvider(id).future)).length, 1);
    });

    test('Ok(false) si ya estaba', () async {
      final id = _ok(await repo.create('A')).id;
      _ok(await repo.addSong(id, _song(1)));
      await load();
      expect(_ok(await notifier().addSong(id, _song(1))), isFalse);
      expect((await reloaded()).single.length, 1);
    });

    test('Err se devuelve', () async {
      final id = _ok(await repo.create('A')).id;
      await load();
      flaky.addSongFailures = 1;
      expect((await notifier().addSong(id, _song(1))).isErr, isTrue);
      expect((await reloaded()).single.length, 0);
    });
  });

  test('importFromYoutube crea la playlist y refresca la lista', () async {
    final importing = ProviderContainer.test(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(flaky),
        downloadedKeysProvider.overrideWithValue(const {}),
        youtubePlaylistImporterProvider.overrideWithValue(
          YoutubePlaylistImporter(
            flaky,
            (_) async => ('Mi mix', [_song(1), _song(2)]),
          ),
        ),
      ],
    );
    importing.listen(playlistsProvider, (_, _) {});
    expect(await importing.read(playlistsProvider.future), isEmpty);

    final result = _ok(
      await importing
          .read(playlistsProvider.notifier)
          .importFromYoutube('PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H'),
    );

    expect(result.imported, 2);
    final list = await importing.read(playlistsProvider.future);
    expect(_names(list), ['Mi mix']);
    expect(list.single.length, 2);
  });

  test('toggleLike refresca la lista y el detalle de "Me encanta"', () async {
    final settings = SettingsDao(db);
    final liking = ProviderContainer.test(
      overrides: [
        songDaoProvider.overrideWithValue(songDao),
        playlistDaoProvider.overrideWithValue(playlistDao),
        settingsDaoProvider.overrideWithValue(settings),
        likedPlaylistFromRepositories,
        downloadedKeysProvider.overrideWithValue(const {}),
      ],
    );
    liking.listen(playlistsProvider, (_, _) {});
    expect(await liking.read(playlistsProvider.future), isEmpty);
    final likedSongs = liking.read(likedSongsProvider.notifier);

    final liked = _ok(await likedSongs.toggle(_song(1)));

    final list = await liking.read(playlistsProvider.future);
    expect(_names(list), [LikedPlaylist.name]);
    expect(list.single.length, 1);

    final likedId = list.single.id;
    liking.listen(playlistProvider(likedId), (_, _) {});
    expect((await liking.read(playlistProvider(likedId).future)).length, 1);

    _ok(await likedSongs.toggle(liked));

    expect((await liking.read(playlistProvider(likedId).future)).length, 0);
    expect((await liking.read(playlistsProvider.future)).single.length, 0);
  });
}
