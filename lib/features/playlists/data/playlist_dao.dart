import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/song_dao.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/song.dart';

/// Tablas `playlists` + `playlist_songs`.
///
/// El orden se guarda en `position`. Para reordenar o quitar canciones se
/// reescribe el orden completo de esa playlist dentro de una transacción:
/// es simple, siempre consistente, y una playlist personal rara vez supera
/// unos cientos de filas.
class PlaylistDao {
  PlaylistDao(AppDatabase database, this._songDao) : _db = database.db {
    // Si cambia una canción (p. ej. termina su descarga) las playlists que
    // la contienen también deben repintarse.
    _songSub = _songDao.changes.listen((_) => _notify());
  }

  final Database _db;
  final SongDao _songDao;
  late final StreamSubscription<void> _songSub;
  final _changes = StreamController<void>.broadcast();
  static const _uuid = Uuid();

  Stream<void> get changes => _changes.stream;

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  Future<List<Playlist>> all() async {
    final rows = await _db.query('playlists', orderBy: 'updated_at DESC');
    return [
      for (final row in rows)
        Playlist.fromMap(row, songs: await _songsOf(row['id']! as String)),
    ];
  }

  Future<Playlist?> findById(String id) async {
    final rows = await _db.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Playlist.fromMap(rows.first, songs: await _songsOf(id));
  }

  Future<List<Song>> _songsOf(String playlistId, [DatabaseExecutor? db]) async {
    final rows = await (db ?? _db).rawQuery(
      'SELECT s.* FROM playlist_songs ps '
      'JOIN songs s ON s.id = ps.song_id '
      'WHERE ps.playlist_id = ? ORDER BY ps.position',
      [playlistId],
    );
    return rows.map(Song.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Escritura
  // ---------------------------------------------------------------------------

  Future<Playlist> create(String name, {String? description}) async {
    final now = DateTime.now();
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name.trim(),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('playlists', playlist.toMap());
    _notify();
    return playlist;
  }

  Future<void> rename(String id, String name, {String? description}) async {
    await _db.update(
      'playlists',
      {
        'name': name.trim(),
        'description': description,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  /// Borra la playlist; las canciones y sus descargas no se tocan.
  Future<void> delete(String id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  /// Añade al final. Devuelve false si la canción ya estaba.
  Future<bool> addSong(String playlistId, Song song) async {
    final saved = await _songDao.upsert(song);
    final added = await _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      if (ids.contains(saved.id)) return false;
      await _writeOrder(txn, playlistId, [...ids, saved.id]);
      return true;
    });
    if (added) _notify();
    return added;
  }

  Future<void> removeAt(String playlistId, int index) async {
    await _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      ids.removeAt(index);
      await _writeOrder(txn, playlistId, ids);
    });
    _notify();
  }

  /// [newIndex] es la posición final (ya corregida).
  Future<void> move(String playlistId, int oldIndex, int newIndex) async {
    await _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      final id = ids.removeAt(oldIndex);
      ids.insert(newIndex, id);
      await _writeOrder(txn, playlistId, ids);
    });
    _notify();
  }

  Future<List<String>> _songIdsOf(Transaction txn, String playlistId) async {
    final rows = await txn.query(
      'playlist_songs',
      columns: ['song_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position',
    );
    return [for (final r in rows) r['song_id']! as String];
  }

  Future<void> _writeOrder(
    Transaction txn,
    String playlistId,
    List<String> songIds,
  ) async {
    await txn.delete(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    final batch = txn.batch();
    for (var i = 0; i < songIds.length; i++) {
      batch.insert('playlist_songs', {
        'playlist_id': playlistId,
        'song_id': songIds[i],
        'position': i,
      });
    }
    batch.update(
      'playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
    await batch.commit(noResult: true);
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _songSub.cancel();
    await _changes.close();
  }
}
