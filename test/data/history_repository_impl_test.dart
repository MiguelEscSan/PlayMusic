import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/history/data/history_dao.dart';
import 'package:sponify/features/history/data/history_repository_impl.dart';
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
  late HistoryRepositoryImpl repo;
  var now = 0;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    now = 0;
    repo = HistoryRepositoryImpl(
      HistoryDao(
        db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(now += 1000),
      ),
    );
  });

  tearDown(() => db.close());

  Future<Song> saved(String id) async =>
      (await songs.upsert(SongModel.fromEntity(_song(id)))).toEntity();

  List<String> titles(Result<List<Song>> result) => [
    for (final s in result.valueOrNull!) s.title,
  ];

  test('record + recentSongs map rows to domain songs', () async {
    final a = await saved('a');
    final b = await saved('b');
    expect(await repo.record(a), const Ok(unit));
    expect(await repo.record(b), const Ok(unit));
    final recent = await repo.recentSongs();
    expect(recent.valueOrNull, everyElement(isA<Song>()));
    expect(titles(recent), ['Tb', 'Ta']);
  });

  test('topSongs orders by number of plays', () async {
    final a = await saved('a');
    final b = await saved('b');
    for (final s in [a, b, b]) {
      await repo.record(s);
    }
    expect(titles(await repo.topSongs()), ['Tb', 'Ta']);
  });

  test('clear empties the history', () async {
    await repo.record(await saved('a'));
    expect(await repo.clear(), const Ok(unit));
    expect((await repo.recentSongs()).valueOrNull, isEmpty);
    expect((await repo.topSongs()).valueOrNull, isEmpty);
  });

  test('a song without id is not recorded', () async {
    expect(await repo.record(_song('x')), const Ok(unit));
    expect((await repo.recentSongs()).valueOrNull, isEmpty);
  });

  test('a database failure becomes Err(DatabaseFailure)', () async {
    final a = await saved('a');
    await db.close();
    final results = <Result<Object?>>[
      await repo.record(a),
      await repo.recentSongs(),
      await repo.topSongs(),
      await repo.clear(),
    ];
    for (final result in results) {
      expect(result.failureOrNull, isA<DatabaseFailure>());
    }
  });
}
