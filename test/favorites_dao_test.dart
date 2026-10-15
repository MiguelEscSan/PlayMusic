import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
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
  late SongDao dao;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = SongDao(db);
  });

  tearDown(() => db.close());

  test('marcar y desmarcar "me gusta"', () async {
    final s = await dao.upsert(_song('1'));
    expect(s.isLiked, isFalse);

    await dao.setLiked(s.id, true);
    final liked = (await dao.findById(s.id))!;
    expect(liked.isLiked, isTrue);
    expect(liked.likedAt, isNotNull);
    expect(await dao.liked(), [liked]);

    await dao.setLiked(s.id, false);
    expect((await dao.findById(s.id))!.isLiked, isFalse);
    expect(await dao.liked(), isEmpty);
  });

  test(
    'liked() ordena por fecha de "me gusta", la más reciente primero',
    () async {
      final ids = <String>[];
      for (final id in ['1', '2', '3']) {
        ids.add((await dao.upsert(_song(id))).id);
      }
      for (final id in [ids[1], ids[0], ids[2]]) {
        await dao.setLiked(id, true);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final titles = [for (final s in await dao.liked()) s.title];
      expect(titles, ['T3', 'T1', 'T2']);
    },
  );

  test('upsert no borra el "me gusta"', () async {
    final s = await dao.upsert(_song('1'));
    await dao.setLiked(s.id, true);

    final again = await dao.upsert(_song('1').copyWith(title: 'Nuevo'));
    expect(again.isLiked, isTrue);
    final stored = (await dao.findById(s.id))!;
    expect(stored.title, 'Nuevo');
    expect(stored.isLiked, isTrue);
  });

  test('setLiked notifica cambios', () async {
    final s = await dao.upsert(_song('1'));
    final next = dao.changes.first;
    await dao.setLiked(s.id, true);
    await expectLater(next, completes);
  });
}
