import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/features/search/data/search_history_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SearchHistoryDao dao;
  late DateTime now;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime(2026, 1, 1);
    // Reloj que avanza un segundo en cada búsqueda.
    dao = SearchHistoryDao(
      db,
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  });

  tearDown(() => db.close());

  test('la más reciente primero y sin duplicados', () async {
    await dao.record('rosalia');
    await dao.record('bad bunny');
    await dao.record('rosalia');
    expect(await dao.recent(), ['rosalia', 'bad bunny']);
  });

  test('recorta espacios, ignora vacías y no distingue mayúsculas', () async {
    await dao.record('  quevedo  ');
    await dao.record('   ');
    await dao.record('');
    await dao.record('Quevedo');
    expect(await dao.recent(), ['Quevedo']);
  });

  test('respeta el límite de recent y conserva como máximo 50', () async {
    for (var i = 0; i < 60; i++) {
      await dao.record('q$i');
    }
    expect(await dao.recent(limit: 3), ['q59', 'q58', 'q57']);
    final all = await dao.recent(limit: 100);
    expect(all, hasLength(50));
    expect(all.last, 'q10');
  });

  test('misma marca de tiempo: gana la última apuntada', () async {
    final fixed = SearchHistoryDao(db, clock: () => DateTime(2026));
    await fixed.record('a');
    await fixed.record('b');
    expect(await fixed.recent(), ['b', 'a']);
  });

  test('quitar una y borrar todo', () async {
    await dao.record('a');
    await dao.record('b');
    await dao.remove('a');
    expect(await dao.recent(), ['b']);
    await dao.clear();
    expect(await dao.recent(), isEmpty);
  });
}
