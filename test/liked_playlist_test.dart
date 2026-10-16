import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/data/repositories/settings_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/favorites/data/liked_playlist.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/shared/song_actions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_feature_repositories.dart';
import 'domain/fakes/fake_playlist_repository.dart';
import 'domain/fakes/fake_song_repository.dart';
import 'helpers/liked_playlist_override.dart';

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songDao;
  late PlaylistDao playlistDao;
  late SongRepositoryImpl songs;
  late PlaylistRepositoryImpl playlists;
  late SettingsDao settings;
  late LikedPlaylist liked;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    playlistDao = PlaylistDao(db, songDao);
    songs = SongRepositoryImpl(songDao);
    playlists = PlaylistRepositoryImpl(playlistDao);
    settings = SettingsDao(db);
    liked = LikedPlaylist(
      playlists: playlists,
      songs: songs,
      settings: SettingsRepositoryImpl(settings),
    );
  });

  tearDown(() => db.close());

  List<String> titles(List<Song> s) => [for (final x in s) x.title];

  Future<String> ensure() async => _ok(await liked.ensure());

  Future<List<Song>> likedSongs() async =>
      _ok(await playlists.findById(await ensure())).songs;

  Future<Song> save(String id) async => _ok(await songs.save(_song(id)));

  Future<void> setLiked(Song s, bool value) async =>
      _ok(await songs.setLiked(s.id, liked: value));

  Future<Song> reload(Song s) async => _ok(await songs.findById(s.id));

  test('ensure() crea "Me encanta" una sola vez', () async {
    final id = await ensure();
    expect(await ensure(), id);
    final all = _ok(await playlists.getAll());
    expect(all, hasLength(1));
    expect(all.single.name, 'Me encanta');
  });

  test('al crearla incluye los "me gusta" previos, del más antiguo', () async {
    for (final id in ['1', '2']) {
      await setLiked(await save(id), true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await save('3'); // sin "me gusta"

    expect(titles(await likedSongs()), ['T1', 'T2']);
  });

  test('sync() añade y quita según isLiked', () async {
    final s = await save('1');
    await setLiked(s, true);
    _ok(await liked.sync(await reload(s)));
    expect(titles(await likedSongs()), ['T1']);

    await setLiked(s, false);
    _ok(await liked.sync(await reload(s)));
    expect(await likedSongs(), isEmpty);
  });

  test('renombrada sigue enlazada; borrada se vuelve a crear', () async {
    final id = await ensure();
    _ok(await playlists.rename(id, 'Favoritas'));
    expect(await ensure(), id);

    _ok(await playlists.delete(id));
    final s = await save('1');
    await setLiked(s, true);
    _ok(await liked.sync(await reload(s)));
    final newId = await ensure();
    expect(newId, isNot(id));
    expect(titles(await likedSongs()), ['T1']);
  });

  test('dos sync() a la vez no crean dos playlists', () async {
    final a = await save('1');
    final b = await save('2');
    await setLiked(a, true);
    await setLiked(b, true);
    await Future.wait([
      liked.sync(await reload(a)),
      liked.sync(await reload(b)),
    ]);
    expect(_ok(await playlists.getAll()), hasLength(1));
    expect(await likedSongs(), hasLength(2));
  });

  test('un fallo de los repositorios llega como Err, sin lanzar', () async {
    final failing = LikedPlaylist(
      playlists: FakePlaylistRepository(),
      songs: FakeSongRepository(),
      settings: SettingsRepositoryImpl(settings),
    );

    expect((await failing.ensure()).isErr, isTrue);
    expect((await failing.sync(_song('1'))).isErr, isTrue);
  });

  test(
    'si no se pueden leer los ajustes devuelve Err sin crear nada',
    () async {
      const failure = DatabaseFailure('disk full');
      final failing = LikedPlaylist(
        playlists: playlists,
        songs: songs,
        settings: FakeSettingsRepository()..failure = failure,
      );

      expect(await failing.ensure(), const Err<String>(failure));
      expect(_ok(await playlists.getAll()), isEmpty);
    },
  );

  test(
    'si el relleno inicial falla, el siguiente ensure() lo completa',
    () async {
      for (final id in ['1', '2']) {
        await setLiked(await save(id), true);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final flakyRepo = FlakyPlaylistRepository(playlists)..addSongFailures = 1;
      final flaky = LikedPlaylist(
        playlists: flakyRepo,
        songs: songs,
        settings: SettingsRepositoryImpl(settings),
      );

      expect((await flaky.ensure()).isErr, isTrue);

      final id = _ok(await flaky.ensure());
      final all = _ok(await playlists.getAll());
      expect(all, hasLength(1), reason: 'una sola "Me encanta"');
      expect(all.single.id, id);
      expect(titles(_ok(await playlists.findById(id)).songs), ['T1', 'T2']);
      expect(await settings.get(SettingsKeys.likedPlaylistId), id);
    },
  );

  test('SongActions.toggleLike añade y quita de "Me encanta"', () async {
    final container = ProviderContainer(
      overrides: [
        songDaoProvider.overrideWithValue(songDao),
        playlistDaoProvider.overrideWithValue(playlistDao),
        settingsDaoProvider.overrideWithValue(settings),
        likedPlaylistFromRepositories,
      ],
    );
    addTearDown(container.dispose);
    final actions = container.read(songActionsProvider);

    final likedSong = _ok(await actions.toggleLike(_song('1')));
    expect(likedSong.isLiked, isTrue);
    expect(titles(await likedSongs()), ['T1']);

    final unliked = _ok(await actions.toggleLike(likedSong));
    expect(unliked.isLiked, isFalse);
    expect(await likedSongs(), isEmpty);
  });
}
