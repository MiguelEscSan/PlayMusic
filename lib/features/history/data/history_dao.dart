import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/data/models/song_model.dart';

/// Tabla `play_history`: una fila por cada vez que empieza a sonar una
/// canción. Se guarda cada escucha (no solo la última) para poder sacar
/// estadísticas más adelante, recortando a [maxEntries] filas.
class HistoryDao {
  HistoryDao(
    AppDatabase database, {
    this.maxEntries = 500,
    DateTime Function()? clock,
  }) : _db = database.db,
       _clock = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _clock;

  /// Escuchas que se conservan como máximo.
  final int maxEntries;

  /// Apunta una escucha de [songId] ahora y recorta el historial.
  Future<void> record(String songId) async {
    await _db.transaction((txn) async {
      await txn.insert('play_history', {
        'song_id': songId,
        'played_at': _clock().millisecondsSinceEpoch,
      });
      await txn.rawDelete(
        'DELETE FROM play_history WHERE id NOT IN ('
        'SELECT id FROM play_history '
        'ORDER BY played_at DESC, id DESC LIMIT ?)',
        [maxEntries],
      );
    });
  }

  /// Canciones distintas, la escuchada más recientemente primero.
  Future<List<SongModel>> recent({int limit = 20}) async {
    final rows = await _db.rawQuery(
      'SELECT s.* FROM songs s JOIN ('
      'SELECT song_id, MAX(played_at) AS last_played, MAX(id) AS last_id '
      'FROM play_history GROUP BY song_id'
      ') h ON h.song_id = s.id '
      'ORDER BY h.last_played DESC, h.last_id DESC LIMIT ?',
      [limit],
    );
    return rows.map(SongModel.fromMap).toList();
  }

  /// Canciones más escuchadas en los últimos [days] días, por número de
  /// escuchas (desempate: la escucha más reciente primero).
  Future<List<SongModel>> topSongs({int limit = 50, int days = 30}) async {
    final since = _clock()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT s.*, COUNT(*) AS plays, MAX(h.played_at) AS last_played '
      'FROM play_history h JOIN songs s ON s.id = h.song_id '
      'WHERE h.played_at >= ? '
      'GROUP BY s.id '
      'ORDER BY plays DESC, last_played DESC LIMIT ?',
      [since, limit],
    );
    return rows.map(SongModel.fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('play_history');
  }
}
