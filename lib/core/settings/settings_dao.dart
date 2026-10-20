import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Claves de los ajustes. Solo las usa la capa de datos
/// (`SettingsRepositoryImpl`): el resto de la app lee los ajustes con
/// métodos tipados de `ISettingsRepository`.
abstract final class SettingsKeys {
  /// Radio automática al terminar la cola (por defecto activada).
  static const radioEnabled = 'radio.enabled';

  /// Descargar solo con wifi (por defecto desactivado).
  static const downloadOnlyWifi = 'downloads.only_wifi';

  /// Id de la playlist "Me encanta" (la crea `LikedPlaylist`).
  static const likedPlaylistId = 'favorites.playlist_id';

  /// Última reproducción (cola, índice y posición) para retomarla al abrir.
  static const lastPlayback = 'playback.last';
}

/// Ajustes de la app en la tabla `settings` (clave/valor de texto).
class SettingsDao {
  SettingsDao(AppDatabase database) : _db = database.db;

  final Database _db;

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
  }

  Future<bool> getBool(String key, {required bool fallback}) async =>
      switch (await get(key)) {
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  Future<void> setBool(String key, bool value) => set(key, '$value');
}
