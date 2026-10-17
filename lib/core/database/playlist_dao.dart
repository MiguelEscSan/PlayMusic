import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'song_dao.dart';
import '../data/models/playlist_model.dart';
import '../data/models/song_model.dart';

/// Tablas `playlists` + `playlist_songs`.
///
/// El orden se guarda en `position`. Para reordenar o quitar canciones se
/// reescribe el orden completo de esa playlist dentro de una transacción:
/// es simple, siempre consistente, y una playlist personal rara vez supera
/// unos cientos de filas.
///
/// Solo lee y escribe: no avisa de los cambios. Quien modifica una playlist
/// (los notifiers de presentación) refresca lo que dependa de ella.
class PlaylistDao {
  PlaylistDao(AppDatabase database, this._songDao) : _db = database.db;

  final Database _db;
  final SongDao _songDao;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  Future<List<PlaylistModel>> all() async {
    final rows = await _db.query('playlists', orderBy: 'updated_at DESC');
    return [
      for (final row in rows)
        PlaylistModel.fromMap(row, songs: await _songsOf(row['id']! as String)),
    ];
  }

  Future<PlaylistModel?> findById(String id) async {
    final rows = await _db.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PlaylistModel.fromMap(rows.first, songs: await _songsOf(id));
  }

  Future<List<SongModel>> _songsOf(
    String playlistId, [
    DatabaseExecutor? db,
  ]) async {
    final rows = await (db ?? _db).rawQuery(
      'SELECT s.* FROM playlist_songs ps '
      'JOIN songs s ON s.id = ps.song_id '
      'WHERE ps.playlist_id = ? ORDER BY ps.position',
      [playlistId],
    );
    return rows.map(SongModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Escritura
  // ---------------------------------------------------------------------------

  Future<PlaylistModel> create(String name, {String? description}) async {
    final now = DateTime.now();
    final playlist = PlaylistModel(
      id: _uuid.v4(),
      name: name.trim(),
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('playlists', playlist.toMap());
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
  }

  /// Portada personalizada (ruta local); null vuelve a la automática.
  Future<void> setCover(String id, String? coverUrl) async {
    await _db.update(
      'playlists',
      {
        'cover_url': coverUrl,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra la playlist; las canciones y sus descargas no se tocan.
  Future<void> delete(String id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  /// Añade al final. Devuelve false si la canción ya estaba.
  ///
  /// El upsert de la canción y la escritura del orden comparten transacción:
  /// si falla un paso no queda ni la canción huérfana ni la playlist a medias.
  Future<bool> addSong(String playlistId, SongModel song) async {
    return _db.transaction((txn) async {
      final saved = await _songDao.upsert(song, executor: txn);
      final ids = await _songIdsOf(txn, playlistId);
      if (ids.contains(saved.id)) return false;
      await _writeOrder(txn, playlistId, [...ids, saved.id]);
      return true;
    });
  }

  Future<void> removeAt(String playlistId, int index) async {
    await _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      ids.removeAt(index);
      await _writeOrder(txn, playlistId, ids);
    });
  }

  /// Quita la canción con id [songId]. Devuelve false si no estaba.
  Future<bool> removeSong(String playlistId, String songId) async {
    return _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      if (!ids.remove(songId)) return false;
      await _writeOrder(txn, playlistId, ids);
      return true;
    });
  }

  /// [newIndex] es la posición final (ya corregida).
  Future<void> move(String playlistId, int oldIndex, int newIndex) async {
    await _db.transaction((txn) async {
      final ids = await _songIdsOf(txn, playlistId);
      final id = ids.removeAt(oldIndex);
      ids.insert(newIndex, id);
      await _writeOrder(txn, playlistId, ids);
    });
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
}
