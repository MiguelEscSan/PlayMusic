import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// Tabla `search_history`: una fila por texto buscado con la última vez que
/// se buscó. Se conservan como máximo [maxEntries] búsquedas.
class SearchHistoryDao {
  SearchHistoryDao(
    AppDatabase database, {
    this.maxEntries = 50,
    DateTime Function()? clock,
  }) : _db = database.db,
       _clock = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _clock;

  /// Búsquedas que se conservan como máximo.
  final int maxEntries;

  /// Apunta [query] (sin espacios sobrantes) como la búsqueda más reciente.
  /// Si ya existía con otras mayúsculas se sustituye por la nueva forma.
  Future<void> record(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await _db.transaction((txn) async {
      await txn.delete(
        'search_history',
        where: 'query = ? COLLATE NOCASE',
        whereArgs: [q],
      );
      await txn.insert('search_history', {
        'query': q,
        'searched_at': _clock().millisecondsSinceEpoch,
      });
      // El rowid desempata búsquedas con la misma marca de tiempo.
      await txn.rawDelete(
        'DELETE FROM search_history WHERE rowid NOT IN ('
        'SELECT rowid FROM search_history '
        'ORDER BY searched_at DESC, rowid DESC LIMIT ?)',
        [maxEntries],
      );
    });
  }

  /// Búsquedas recientes, la última primero.
  Future<List<String>> recent({int limit = 10}) async {
    final rows = await _db.rawQuery(
      'SELECT query FROM search_history '
      'ORDER BY searched_at DESC, rowid DESC LIMIT ?',
      [limit],
    );
    return [for (final r in rows) r['query']! as String];
  }

  Future<void> remove(String query) async {
    await _db.delete('search_history', where: 'query = ?', whereArgs: [query]);
  }

  Future<void> clear() async {
    await _db.delete('search_history');
  }
}
