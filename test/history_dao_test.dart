import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/features/history/data/history_dao.dart';
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
  late HistoryDao dao;
  late int now;

  // Reloj que avanza 1 ms en cada lectura: cada escucha es posterior.
  DateTime tick() => DateTime.fromMillisecondsSinceEpoch(now++);

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    now = 1000;
    dao = HistoryDao(db, clock: tick);
  });

  tearDown(() => db.close());

  Future<String> saved(String id) async => (await songs.upsert(_song(id))).id;
  List<String> titles(List<SongModel> s) => [for (final x in s) x.title];

  test('recent devuelve lo último primero y sin repetidas', () async {
    final a = await saved('a');
    final b = await saved('b');
    final c = await saved('c');
    await dao.record(a);
    await dao.record(b);
    await dao.record(c);
    await dao.record(a);

    expect(titles(await dao.recent()), ['Ta', 'Tc', 'Tb']);
  });

  test('recent respeta el límite', () async {
    for (final id in ['1', '2', '3', '4']) {
      await dao.record(await saved(id));
    }
    expect(titles(await dao.recent(limit: 2)), ['T4', 'T3']);
  });

  test('record recorta el historial a las escuchas más recientes', () async {
    final small = HistoryDao(db, maxEntries: 3, clock: tick);
    for (final id in ['1', '2', '3', '4', '5']) {
      await small.record(await saved(id));
    }
    expect(await db.db.query('play_history'), hasLength(3));
    expect(titles(await small.recent()), ['T5', 'T4', 'T3']);
  });

  test('clear vacía el historial', () async {
    await dao.record(await saved('a'));
    await dao.clear();
    expect(await dao.recent(), isEmpty);
  });

  test('guarda played_at con el reloj inyectado', () async {
    now = 42;
    await dao.record(await saved('a'));
    final row = (await db.db.query('play_history')).single;
    expect(row['played_at'], 42);
  });

  test('topSongs ordena por escuchas y excluye lo anterior a 30 días', () async {
    now = 40 * Duration.millisecondsPerDay;
    final old = await saved('old');
    await db.db.insert('play_history', {'song_id': old, 'played_at': 1000});
    final a = await saved('a');
    final b = await saved('b');
    final c = await saved('c');
    for (final id in [b, c, c, a, a, a]) {
      await dao.record(id);
    }
    expect(titles(await dao.topSongs()), ['Ta', 'Tc', 'Tb']);
  });
}
