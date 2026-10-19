import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/data/repositories/playlist_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/playlist.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/database/playlist_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Song _song(String sourceId) => Song(
  id: '',
  title: 'T$sourceId',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: sourceId,
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

Failure _err<T>(Result<T> result) {
  expect(result, isA<Err<T>>(), reason: 'expected Err, got $result');
  return (result as Err<T>).failure;
}

List<String> _titles(Playlist p) => [for (final s in p.songs) s.title];

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songDao;
  late PlaylistDao dao;
  late PlaylistRepositoryImpl repo;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    dao = PlaylistDao(db, songDao);
    repo = PlaylistRepositoryImpl(dao);
  });

  tearDown(() => db.close());

  test('create, getAll and findById return domain entities', () async {
    final created = _ok(await repo.create('  Mix ', description: 'd'));
    expect(created, isA<Playlist>());
    expect(created.name, 'Mix');
    expect(created.description, 'd');

    final all = _ok(await repo.getAll());
    expect([for (final p in all) p.id], [created.id]);

    final found = _ok(await repo.findById(created.id));
    expect(found.name, 'Mix');
    expect(found.songs, isEmpty);
  });

  test('findById of a missing id is Err(NotFoundFailure)', () async {
    expect(_err(await repo.findById('missing')), isA<NotFoundFailure>());
  });

  test('rename and delete', () async {
    final p = _ok(await repo.create('Mix'));

    expect(_ok(await repo.rename(p.id, 'Renamed', description: 'x')), unit);
    final renamed = _ok(await repo.findById(p.id));
    expect(renamed.name, 'Renamed');
    expect(renamed.description, 'x');

    expect(_ok(await repo.delete(p.id)), unit);
    expect(_err(await repo.findById(p.id)), isA<NotFoundFailure>());
  });

  test('addSong, duplicate, moveSong and removeSong', () async {
    final p = _ok(await repo.create('Mix'));
    for (final id in ['1', '2', '3']) {
      expect(_ok(await repo.addSong(p.id, _song(id))), isTrue);
    }
    expect(_ok(await repo.addSong(p.id, _song('2'))), isFalse);

    expect(_ok(await repo.moveSong(p.id, 0, 2)), unit);
    final moved = _ok(await repo.findById(p.id));
    expect(_titles(moved), ['T2', 'T3', 'T1']);

    final middle = moved.songs[1];
    expect(_ok(await repo.removeSong(p.id, middle.id)), isTrue);
    expect(_titles(_ok(await repo.findById(p.id))), ['T2', 'T1']);
    expect(_ok(await repo.removeSong(p.id, middle.id)), isFalse);
  });

  test('removeSongAt removes the song at the given position', () async {
    final p = _ok(await repo.create('Mix'));
    for (final id in ['1', '2', '3']) {
      _ok(await repo.addSong(p.id, _song(id)));
    }

    expect(_ok(await repo.removeSongAt(p.id, 1)), unit);
    expect(_titles(_ok(await repo.findById(p.id))), ['T1', 'T3']);
  });

  test('setCover stores and clears the custom cover', () async {
    final p = _ok(await repo.create('Mix'));

    expect(_ok(await repo.setCover(p.id, '/covers/a.jpg')), unit);
    expect(_ok(await repo.findById(p.id)).coverUrl, '/covers/a.jpg');

    expect(_ok(await repo.setCover(p.id, null)), unit);
    expect(_ok(await repo.findById(p.id)).coverUrl, isNull);
  });

  test(
    'a database failure becomes Err(DatabaseFailure) and never throws',
    () async {
      final p = _ok(await repo.create('Mix'));
      await db.close();

      final results = <Result<Object?>>[
        await repo.getAll(),
        await repo.findById(p.id),
        await repo.create('Other'),
        await repo.rename(p.id, 'X'),
        await repo.delete(p.id),
        await repo.addSong(p.id, _song('1')),
        await repo.removeSong(p.id, 'x'),
        await repo.moveSong(p.id, 0, 1),
        await repo.removeSongAt(p.id, 0),
        await repo.setCover(p.id, '/x.jpg'),
      ];

      for (final result in results) {
        final failure = _err(result);
        expect(failure, isA<DatabaseFailure>());
        expect(failure.cause, isA<DatabaseException>());
      }
    },
  );
}
