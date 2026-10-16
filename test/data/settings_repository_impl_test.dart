import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/repositories/settings_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SettingsDao dao;
  late SettingsRepositoryImpl repo;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = SettingsDao(db);
    repo = SettingsRepositoryImpl(dao);
  });

  tearDown(() => db.close());

  test('defaults: radio on, downloads with mobile data, no liked id', () async {
    expect(await repo.getRadioEnabled(), const Ok(true));
    expect(await repo.getDownloadOnlyWifi(), const Ok(false));
    expect(await repo.getLikedPlaylistId(), const Ok<String?>(null));
  });

  test('stores each setting under its own key', () async {
    expect(await repo.setRadioEnabled(false), const Ok(unit));
    expect(await repo.setDownloadOnlyWifi(true), const Ok(unit));
    expect(await repo.setLikedPlaylistId('p1'), const Ok(unit));

    expect(await repo.getRadioEnabled(), const Ok(false));
    expect(await repo.getDownloadOnlyWifi(), const Ok(true));
    expect(await repo.getLikedPlaylistId(), const Ok<String?>('p1'));
    expect(
      await dao.getBool(SettingsKeys.radioEnabled, fallback: true),
      isFalse,
    );
    expect(
      await dao.getBool(SettingsKeys.downloadOnlyWifi, fallback: false),
      isTrue,
    );
    expect(await dao.get(SettingsKeys.likedPlaylistId), 'p1');
  });

  test('a database failure becomes Err(DatabaseFailure)', () async {
    await db.close();
    final results = <Result<Object?>>[
      await repo.getRadioEnabled(),
      await repo.setRadioEnabled(true),
      await repo.getDownloadOnlyWifi(),
      await repo.setDownloadOnlyWifi(true),
      await repo.getLikedPlaylistId(),
      await repo.setLikedPlaylistId('x'),
    ];
    for (final result in results) {
      expect(result.failureOrNull, isA<DatabaseFailure>());
    }
  });
}
