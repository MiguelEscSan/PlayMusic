import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/features/playlists/data/youtube_playlist_importer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

const _url =
    'https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H';
const _id = 'PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late PlaylistDao dao;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = PlaylistDao(db, SongDao(db));
  });

  tearDown(() => db.close());

  List<String> titles(List<Song> s) => [for (final x in s) x.title];

  test('importa la playlist con su título y las canciones en orden', () async {
    String? requested;
    final importer = YoutubePlaylistImporter(dao, (id) async {
      requested = id;
      return ('Mi mix', [_song('1'), _song('2'), _song('3')]);
    });

    final result = await importer.importFromUrl(_url);

    expect(requested, _id);
    expect(result.imported, 3);
    expect(result.skipped, 0);
    final p = (await dao.findById(result.playlistId))!;
    expect(p.name, 'Mi mix');
    expect(titles(p.songs), ['T1', 'T2', 'T3']);
  });

  test('un enlace no válido da error y no crea playlist', () async {
    var fetched = false;
    final importer = YoutubePlaylistImporter(dao, (_) async {
      fetched = true;
      return ('X', [_song('1')]);
    });

    await expectLater(
      importer.importFromUrl('https://example.com/nada'),
      throwsA(isA<InvalidPlaylistLinkException>()),
    );
    expect(fetched, isFalse);
    expect(await dao.all(), isEmpty);
  });

  test('las canciones repetidas y no disponibles se omiten', () async {
    final importer = YoutubePlaylistImporter(
      dao,
      (_) async => ('Mix', [_song('1'), null, _song('2'), _song('1')]),
    );

    final result = await importer.importFromUrl(_id);

    expect(result.imported, 2);
    expect(result.skipped, 2);
    final p = (await dao.findById(result.playlistId))!;
    expect(titles(p.songs), ['T1', 'T2']);
  });

  test('avisa del progreso tras cada canción', () async {
    final importer = YoutubePlaylistImporter(
      dao,
      (_) async => ('Mix', [_song('1'), _song('2')]),
    );
    final calls = <(int, int)>[];

    await importer.importFromUrl(
      _url,
      onProgress: (done, total) => calls.add((done, total)),
    );

    expect(calls, [(0, 2), (1, 2), (2, 2)]);
  });

  test('importa como mucho 500 canciones', () async {
    final importer = YoutubePlaylistImporter(
      dao,
      (_) async => ('Larga', [for (var i = 0; i < 510; i++) _song('$i')]),
    );

    final result = await importer.importFromUrl(_url);

    expect(result.imported, YoutubePlaylistImporter.maxSongs);
  });

  test('sin canciones importables da error y no crea playlist', () async {
    final importer = YoutubePlaylistImporter(
      dao,
      (_) async => ('Vacía', <Song?>[null]),
    );

    await expectLater(
      importer.importFromUrl(_url),
      throwsA(isA<EmptyPlaylistException>()),
    );
    expect(await dao.all(), isEmpty);
  });
}
