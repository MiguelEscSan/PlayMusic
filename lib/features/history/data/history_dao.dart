import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/song.dart';

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

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

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
    _notify();
  }

  /// Canciones distintas, la escuchada más recientemente primero.
  Future<List<Song>> recent({int limit = 20}) async {
    final rows = await _db.rawQuery(
      'SELECT s.* FROM songs s JOIN ('
      'SELECT song_id, MAX(played_at) AS last_played, MAX(id) AS last_id '
      'FROM play_history GROUP BY song_id'
      ') h ON h.song_id = s.id '
      'ORDER BY h.last_played DESC, h.last_id DESC LIMIT ?',
      [limit],
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('play_history');
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
