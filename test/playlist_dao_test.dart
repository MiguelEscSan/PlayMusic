import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/features/search/data/youtube_search_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SongModel _song(String id) => SongModel(
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
  late PlaylistDao dao;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    dao = PlaylistDao(db, songs);
  });

  tearDown(() => db.close());

  List<String> titles(List<SongModel> s) => [for (final x in s) x.title];

  test('añadir, reordenar y quitar mantiene el orden', () async {
    final p = await dao.create('Mix');
    for (final id in ['1', '2', '3']) {
      await dao.addSong(p.id, _song(id));
    }
    expect(await dao.addSong(p.id, _song('2')), isFalse, reason: 'duplicada');

    await dao.move(p.id, 0, 2);
    expect(titles((await dao.findById(p.id))!.songs), ['T2', 'T3', 'T1']);

    await dao.removeAt(p.id, 1);
    expect(titles((await dao.findById(p.id))!.songs), ['T2', 'T1']);
  });

  test('borrar la playlist no borra las canciones', () async {
    final p = await dao.create('Mix');
    await dao.addSong(p.id, _song('1'));
    await dao.delete(p.id);
    expect(await dao.findById(p.id), isNull);
    expect(await songs.findBySource(SongSource.youtube, '1'), isNotNull);
  });

  test('limpieza de títulos de YouTube', () {
    expect(
      YoutubeSearchSource.cleanTitle(
        'Bad Bunny - Tití Me Preguntó (Video Oficial)',
      ),
      'Bad Bunny - Tití Me Preguntó',
    );
    expect(
      YoutubeSearchSource.cleanTitle('Song [Official Lyric Video]'),
      'Song',
    );
    expect(YoutubeSearchSource.cleanTitle('Song (feat. X)'), 'Song (feat. X)');
    expect(YoutubeSearchSource.cleanArtist('Rosalía - Topic'), 'Rosalía');
  });

  test('removeSong quita por id y avisa si no estaba', () async {
    final p = await dao.create('Mix');
    for (final id in ['1', '2', '3']) {
      await dao.addSong(p.id, _song(id));
    }
    final middle = (await dao.findById(p.id))!.songs[1];
    expect(await dao.removeSong(p.id, middle.id), isTrue);
    expect(titles((await dao.findById(p.id))!.songs), ['T1', 'T3']);
    expect(await dao.removeSong(p.id, middle.id), isFalse);
  });
}
