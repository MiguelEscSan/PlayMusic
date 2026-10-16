import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/search/data/search_history_dao.dart';
import 'package:sponify/features/search/data/search_history_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SearchHistoryRepositoryImpl repo;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    var now = DateTime(2026);
    repo = SearchHistoryRepositoryImpl(
      SearchHistoryDao(
        db,
        clock: () => now = now.add(const Duration(seconds: 1)),
      ),
    );
  });

  tearDown(() => db.close());

  test('record, recent, remove and clear', () async {
    expect(await repo.record('rosalia'), const Ok(unit));
    expect(await repo.record('quevedo'), const Ok(unit));
    expect((await repo.recent()).valueOrNull, ['quevedo', 'rosalia']);

    expect(await repo.remove('quevedo'), const Ok(unit));
    expect((await repo.recent()).valueOrNull, ['rosalia']);

    expect(await repo.clear(), const Ok(unit));
    expect((await repo.recent()).valueOrNull, isEmpty);
  });

  test('a database failure becomes Err(DatabaseFailure)', () async {
    await db.close();
    final results = <Result<Object?>>[
      await repo.recent(),
      await repo.record('x'),
      await repo.remove('x'),
      await repo.clear(),
    ];
    for (final result in results) {
      expect(result.failureOrNull, isA<DatabaseFailure>());
    }
  });
}
