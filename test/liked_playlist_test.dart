import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/core/settings/settings_providers.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/data/liked_playlist.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sponify/shared/song_actions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songs;
  late PlaylistDao playlists;
  late SettingsDao settings;
  late LikedPlaylist liked;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    playlists = PlaylistDao(db, songs);
    settings = SettingsDao(db);
    liked = LikedPlaylist(
      playlists: playlists,
      songs: songs,
      settings: settings,
    );
  });

  tearDown(() => db.close());

  List<String> titles(List<Song> s) => [for (final x in s) x.title];

  Future<List<Song>> likedSongs() async =>
      (await playlists.findById(await liked.ensure()))!.songs;

  test('ensure() crea "Me encanta" una sola vez', () async {
    final id = await liked.ensure();
    expect(await liked.ensure(), id);
    final all = await playlists.all();
    expect(all, hasLength(1));
    expect(all.single.name, 'Me encanta');
  });

  test('al crearla incluye los "me gusta" previos, del más antiguo', () async {
    for (final id in ['1', '2']) {
      final s = await songs.upsert(_song(id));
      await songs.setLiked(s.id, true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await songs.upsert(_song('3')); // sin "me gusta"

    expect(titles(await likedSongs()), ['T1', 'T2']);
  });

  test('sync() añade y quita según isLiked', () async {
    final s = await songs.upsert(_song('1'));
    await songs.setLiked(s.id, true);
    await liked.sync((await songs.findById(s.id))!);
    expect(titles(await likedSongs()), ['T1']);

    await songs.setLiked(s.id, false);
    await liked.sync((await songs.findById(s.id))!);
    expect(await likedSongs(), isEmpty);
  });

  test('renombrada sigue enlazada; borrada se vuelve a crear', () async {
    final id = await liked.ensure();
    await playlists.rename(id, 'Favoritas');
    expect(await liked.ensure(), id);

    await playlists.delete(id);
    final s = await songs.upsert(_song('1'));
    await songs.setLiked(s.id, true);
    await liked.sync((await songs.findById(s.id))!);
    final newId = await liked.ensure();
    expect(newId, isNot(id));
    expect(titles(await likedSongs()), ['T1']);
  });

  test('dos sync() a la vez no crean dos playlists', () async {
    final a = await songs.upsert(_song('1'));
    final b = await songs.upsert(_song('2'));
    await songs.setLiked(a.id, true);
    await songs.setLiked(b.id, true);
    await Future.wait([
      liked.sync((await songs.findById(a.id))!),
      liked.sync((await songs.findById(b.id))!),
    ]);
    expect(await playlists.all(), hasLength(1));
    expect(await likedSongs(), hasLength(2));
  });

  test('SongActions.toggleLike añade y quita de "Me encanta"', () async {
    final container = ProviderContainer(
      overrides: [
        songDaoProvider.overrideWithValue(songs),
        playlistDaoProvider.overrideWithValue(playlists),
        settingsDaoProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    final actions = container.read(songActionsProvider);

    final likedSong = await actions.toggleLike(_song('1'));
    expect(likedSong.isLiked, isTrue);
    expect(titles(await likedSongs()), ['T1']);

    final unliked = await actions.toggleLike(likedSong);
    expect(unliked.isLiked, isFalse);
    expect(await likedSongs(), isEmpty);
  });
}
