import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Claves de los ajustes. Centralizadas aquí para que la pantalla de
/// Ajustes y cada funcionalidad usen exactamente la misma.
abstract final class SettingsKeys {
  /// Radio automática al terminar la cola (por defecto activada).
  static const radioEnabled = 'radio.enabled';

  /// Descargar solo con wifi (por defecto desactivado).
  static const downloadOnlyWifi = 'downloads.only_wifi';

  /// Id de la playlist "Me encanta" (la crea `LikedPlaylist`).
  static const likedPlaylistId = 'favorites.playlist_id';
}

/// Ajustes de la app en la tabla `settings` (clave/valor de texto).
class SettingsDao {
  SettingsDao(AppDatabase database) : _db = database.db;

  final Database _db;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<bool> getBool(String key, {required bool fallback}) async =>
      switch (await get(key)) {
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  Future<void> setBool(String key, bool value) => set(key, '$value');

  Future<void> dispose() => _changes.close();
}
