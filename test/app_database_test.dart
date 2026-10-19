import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:koda/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Set<String>> _columns(Database db, String table) async => {
  for (final row in await db.rawQuery('PRAGMA table_info($table)'))
    row['name']! as String,
};

Future<Set<String>> _tables(Database db) async => {
  for (final row in await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    row['name']! as String,
};

void _expectV2Schema(Set<String> tables, Set<String> songColumns) {
  expect(tables, containsAll(['play_history', 'search_history', 'settings']));
  expect(songColumns, contains('liked_at'));
}

void main() {
  sqfliteFfiInit();

  test('una BD nueva se crea directamente con el esquema v2', () async {
    final app = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    expect(await app.db.getVersion(), 2);
    _expectV2Schema(await _tables(app.db), await _columns(app.db, 'songs'));
    await app.close();
  });

  test('migrar de v1 a v2 conserva los datos', () async {
    final tmp = await Directory.systemTemp.createTemp('koda_db');
    final path = p.join(tmp.path, 'koda.db');

    // Esquema v1 tal como se publicó.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE songs (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              album TEXT,
              duration_ms INTEGER NOT NULL,
              artwork_url TEXT,
              source TEXT NOT NULL,
              source_id TEXT NOT NULL,
              stream_url TEXT,
              local_path TEXT,
              file_size_bytes INTEGER,
              downloaded_at INTEGER,
              UNIQUE (source, source_id)
            )''');
          await db.execute('''
            CREATE TABLE playlists (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              cover_url TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )''');
        },
      ),
    );
    await v1.insert('songs', {
      'id': 's1',
      'title': 'T',
      'artist': 'A',
      'duration_ms': 1000,
      'source': 'youtube',
      'source_id': 'yt1',
    });
    await v1.close();

    final app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    expect(await app.db.getVersion(), 2);
    _expectV2Schema(await _tables(app.db), await _columns(app.db, 'songs'));
    final rows = await app.db.query('songs');
    expect(rows.single['title'], 'T');
    expect(rows.single['liked_at'], isNull);
    await app.close();
    await tmp.delete(recursive: true);
  });

  test('copia sponify.db a koda.db una vez y no toca el original', () async {
    final tmp = await Directory.systemTemp.createTemp('koda_legacy');
    final legacy = File(p.join(tmp.path, 'sponify.db'))
      ..writeAsStringSync('legacy');
    final target = p.join(tmp.path, 'koda.db');

    AppDatabase.copyLegacyDatabase(legacy.path, target);
    expect(File(target).readAsStringSync(), 'legacy');
    expect(legacy.existsSync(), isTrue);

    // Si ya existe la BD nueva, no se sobrescribe.
    File(target).writeAsStringSync('new');
    AppDatabase.copyLegacyDatabase(legacy.path, target);
    expect(File(target).readAsStringSync(), 'new');

    await tmp.delete(recursive: true);
  });
}
