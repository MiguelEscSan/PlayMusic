import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/data/repositories/song_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
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

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao dao;
  late SongRepositoryImpl repo;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = SongDao(db);
    repo = SongRepositoryImpl(dao);
  });

  tearDown(() => db.close());

  test(
    'save persists the song and returns a domain entity with an id',
    () async {
      final saved = _ok(await repo.save(_song('1')));

      expect(saved, isA<Song>());
      expect(saved.id, isNotEmpty);
      expect(saved.title, 'T1');

      final again = _ok(await repo.save(_song('1').copyWith(title: 'New')));
      expect(again.id, saved.id, reason: 'upsert keeps the id by source');
      expect(again.title, 'New');
    },
  );

  test('findById returns the entity when it exists', () async {
    final saved = _ok(await repo.save(_song('1')));

    final found = _ok(await repo.findById(saved.id));
    expect(found.id, saved.id);
    expect(found.sourceId, '1');
  });

  test('findById of a missing id is Err(NotFoundFailure)', () async {
    expect(_err(await repo.findById('missing')), isA<NotFoundFailure>());
  });

  test('findBySource returns the persisted entity', () async {
    final saved = _ok(await repo.save(_song('1')));

    final found = _ok(await repo.findBySource(SongSource.youtube, '1'));
    expect(found, isA<Song>());
    expect(found.id, saved.id);
  });

  test(
    'findBySource of an unknown source id is Err(NotFoundFailure)',
    () async {
      expect(
        _err(await repo.findBySource(SongSource.youtube, 'missing')),
        isA<NotFoundFailure>(),
      );
    },
  );

  test(
    'markDownloaded stores the file and returns the updated entity',
    () async {
      final saved = _ok(await repo.save(_song('1')));

      final updated = _ok(
        await repo.markDownloaded(saved.id, localPath: '/a.m4a', sizeBytes: 42),
      );
      expect(updated.id, saved.id);
      expect(updated.localPath, '/a.m4a');
      expect(updated.fileSizeBytes, 42);
      expect(updated.downloadedAt, isNotNull);
      expect(updated.isDownloaded, isTrue);
      expect(_ok(await repo.getDownloadedBytes()), 42);
    },
  );

  test('markDownloaded of a missing id is Err(NotFoundFailure)', () async {
    expect(
      _err(await repo.markDownloaded('missing', localPath: '/x', sizeBytes: 1)),
      isA<NotFoundFailure>(),
    );
  });

  test('setLiked and getLiked round-trip through the DAO', () async {
    final a = _ok(await repo.save(_song('a')));
    _ok(await repo.save(_song('b')));

    expect(_ok(await repo.setLiked(a.id, liked: true)), unit);
    final liked = _ok(await repo.getLiked());
    expect([for (final s in liked) s.id], [a.id]);
    expect(liked.single.isLiked, isTrue);

    _ok(await repo.setLiked(a.id, liked: false));
    expect(_ok(await repo.getLiked()), isEmpty);
  });

  test('getDownloaded, getDownloadedBytes and clearDownload', () async {
    final a = _ok(await repo.save(_song('a')));
    _ok(await repo.save(_song('b')));
    await dao.markDownloaded(a.id, localPath: '/a.m4a', sizeBytes: 300);

    final downloaded = _ok(await repo.getDownloaded());
    expect([for (final s in downloaded) s.id], [a.id]);
    expect(downloaded.single.localPath, '/a.m4a');
    expect(_ok(await repo.getDownloadedBytes()), 300);

    expect(_ok(await repo.clearDownload(a.id)), unit);
    expect(_ok(await repo.getDownloaded()), isEmpty);
    expect(_ok(await repo.getDownloadedBytes()), 0);
  });

  test(
    'a database failure becomes Err(DatabaseFailure) and never throws',
    () async {
      await db.close();

      final results = <Result<Object?>>[
        await repo.save(_song('1')),
        await repo.findById('x'),
        await repo.getDownloaded(),
        await repo.getDownloadedBytes(),
        await repo.getLiked(),
        await repo.setLiked('x', liked: true),
        await repo.clearDownload('x'),
        await repo.findBySource(SongSource.youtube, 'x'),
        await repo.markDownloaded('x', localPath: '/x', sizeBytes: 1),
      ];

      for (final result in results) {
        final failure = _err(result);
        expect(failure, isA<DatabaseFailure>());
        expect(failure.cause, isA<DatabaseException>());
        expect(failure.stackTrace, isNotNull);
      }
    },
  );
}
