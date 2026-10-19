import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Apertura y migraciones de la base de datos local.
///
/// Cada cambio de esquema sube [_version] y añade un `case` en [_onUpgrade];
/// nunca se edita una migración ya publicada (los usuarios con el APK
/// anterior la necesitan tal cual).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _fileName = 'koda.db';
  static const _legacyFileName = 'sponify.db';
  static const _version = 2;

  /// Abre (o crea) la BD en el directorio por defecto de sqflite.
  /// [factory] y [path] permiten usar sqflite_common_ffi en memoria en tests.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final String dbPath;
    if (path != null) {
      dbPath = path;
    } else {
      final dir = await f.getDatabasesPath();
      dbPath = p.join(dir, _fileName);
      copyLegacyDatabase(p.join(dir, _legacyFileName), dbPath);
    }
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  /// Copia la BD de la versión con el nombre antiguo (sponify.db) una sola
  /// vez, para que quienes ya usaban la app no pierdan su biblioteca.
  /// Nunca borra el original; si la copia falla, se arranca con BD nueva.
  static void copyLegacyDatabase(String legacyPath, String newPath) {
    try {
      final legacy = File(legacyPath);
      final target = File(newPath);
      if (target.existsSync() || !legacy.existsSync()) return;
      legacy.copySync(newPath);
    } on FileSystemException {
      // Sin copia: la app arranca con una base vacía.
    }
  }

  /// Crea el esquema v1 y le aplica las migraciones: así una instalación
  /// nueva y una actualizada acaban exactamente con las mismas tablas.
  static Future<void> _onCreate(Database db, int version) async {
    await _createV1(db);
    await _onUpgrade(db, 1, version);
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch()
      ..execute('''
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
        )''')
      ..execute(
        'CREATE INDEX idx_songs_downloaded ON songs(downloaded_at) '
        'WHERE local_path IS NOT NULL',
      )
      ..execute('''
        CREATE TABLE playlists (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          cover_url TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE playlist_songs (
          playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
          song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
          position INTEGER NOT NULL,
          PRIMARY KEY (playlist_id, position)
        )''');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      switch (v) {
        case 2:
          await _migrateToV2(db);
      }
    }
  }

  /// v2: tablas y columnas de Favoritos, Historial, Búsquedas y Ajustes.
  static Future<void> _migrateToV2(Database db) async {
    final batch = db.batch()
      // Favoritos: null = no le gusta; si no, cuándo se marcó.
      ..execute('ALTER TABLE songs ADD COLUMN liked_at INTEGER')
      ..execute(
        'CREATE INDEX idx_songs_liked ON songs(liked_at) '
        'WHERE liked_at IS NOT NULL',
      )
      // Historial de reproducción: una fila por escucha.
      ..execute('''
        CREATE TABLE play_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
          played_at INTEGER NOT NULL
        )''')
      ..execute(
        'CREATE INDEX idx_play_history_played ON play_history(played_at)',
      )
      // Búsquedas recientes: una fila por texto, con la última vez.
      ..execute('''
        CREATE TABLE search_history (
          query TEXT PRIMARY KEY,
          searched_at INTEGER NOT NULL
        )''')
      // Ajustes de la app como clave/valor.
      ..execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
