import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/models/song_model.dart';
import 'app_database.dart';

/// Acceso a la tabla `songs` (CRUD). No avisa de cambios: quien escribe
/// recarga los notifiers afectados (descargas, favoritas, playlists).
class SongDao {
  SongDao(AppDatabase database) : _db = database.db;

  final Database _db;
  static const _uuid = Uuid();

  /// Guarda una canción (p. ej. un resultado de búsqueda) y devuelve la
  /// versión persistida. Si ya existía por `source + sourceId` conserva su
  /// id y su descarga, y solo refresca los metadatos.
  ///
  /// Con [executor] (p. ej. el `txn` de una transacción) la escritura se une
  /// a esa unidad de trabajo; sin él usa la conexión base.
  Future<SongModel> upsert(SongModel song, {DatabaseExecutor? executor}) async {
    final db = executor ?? _db;
    final existing = await findBySource(
      song.source,
      song.sourceId,
      executor: db,
    );
    if (existing != null) {
      final merged = existing.copyWith(
        title: song.title,
        artist: song.artist,
        album: song.album ?? existing.album,
        durationMs: song.durationMs,
        artworkUrl: song.artworkUrl ?? existing.artworkUrl,
        streamUrl: song.streamUrl ?? existing.streamUrl,
      );
      await db.update(
        'songs',
        merged.toJson(),
        where: 'id = ?',
        whereArgs: [merged.id],
      );
      return merged;
    }
    final created = song.id.isEmpty ? song.copyWith(id: _uuid.v4()) : song;
    await db.insert('songs', created.toJson());
    return created;
  }

  Future<SongModel?> findById(String id, {DatabaseExecutor? executor}) async {
    final rows = await (executor ?? _db).query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : SongModel.fromJson(rows.first);
  }

  Future<SongModel?> findBySource(
    SongSource source,
    String sourceId, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? _db).query(
      'songs',
      where: 'source = ? AND source_id = ?',
      whereArgs: [source.name, sourceId],
    );
    return rows.isEmpty ? null : SongModel.fromJson(rows.first);
  }

  /// Canciones descargadas, las más recientes primero.
  Future<List<SongModel>> downloaded() async {
    final rows = await _db.query(
      'songs',
      where: 'local_path IS NOT NULL',
      orderBy: 'downloaded_at DESC',
    );
    return rows.map(SongModel.fromJson).toList();
  }

  /// Espacio total ocupado por las descargas, en bytes.
  Future<int> downloadedBytes() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(file_size_bytes), 0) AS total FROM songs '
      'WHERE local_path IS NOT NULL',
    );
    return rows.first['total']! as int;
  }

  /// Guarda el archivo descargado de [id]. Devuelve la canción actualizada,
  /// o null si [id] no existe.
  Future<SongModel?> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _db;
    await db.update(
      'songs',
      {
        'local_path': localPath,
        'file_size_bytes': sizeBytes,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return findById(id, executor: db);
  }

  Future<void> clearDownload(String id, {DatabaseExecutor? executor}) async {
    await (executor ?? _db).update(
      'songs',
      {'local_path': null, 'file_size_bytes': null, 'downloaded_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marca o desmarca "me gusta". Es la única vía que escribe `liked_at`.
  Future<void> setLiked(
    String songId,
    bool liked, {
    DatabaseExecutor? executor,
  }) async {
    await (executor ?? _db).update(
      'songs',
      {'liked_at': liked ? DateTime.now().millisecondsSinceEpoch : null},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  /// Canciones con "me gusta", la última marcada primero.
  Future<List<SongModel>> liked() async {
    final rows = await _db.query(
      'songs',
      where: 'liked_at IS NOT NULL',
      orderBy: 'liked_at DESC',
    );
    return rows.map(SongModel.fromJson).toList();
  }
}
