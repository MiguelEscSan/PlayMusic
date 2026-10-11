import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/song.dart';
import 'app_database.dart';

/// Acceso a la tabla `songs`. Además de CRUD expone [changes], que emite
/// cada vez que algo cambia, para que la UI (Descargas, biblioteca) se
/// refresque sola.
class SongDao {
  SongDao(AppDatabase database) : _db = database.db;

  final Database _db;
  final _changes = StreamController<void>.broadcast();
  static const _uuid = Uuid();

  Stream<void> get changes => _changes.stream;

  /// Guarda una canción (p. ej. un resultado de búsqueda) y devuelve la
  /// versión persistida. Si ya existía por `source + sourceId` conserva su
  /// id y su descarga, y solo refresca los metadatos.
  Future<Song> upsert(Song song) async {
    final existing = await findBySource(song.source, song.sourceId);
    if (existing != null) {
      final merged = existing.copyWith(
        title: song.title,
        artist: song.artist,
        album: song.album,
        durationMs: song.durationMs,
        artworkUrl: song.artworkUrl,
        streamUrl: song.streamUrl,
      );
      await _db.update(
        'songs',
        merged.toMap(),
        where: 'id = ?',
        whereArgs: [merged.id],
      );
      _notify();
      return merged;
    }
    final created = song.id.isEmpty ? song.copyWith(id: _uuid.v4()) : song;
    await _db.insert('songs', created.toMap());
    _notify();
    return created;
  }

  Future<Song?> findById(String id) async {
    final rows = await _db.query('songs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<Song?> findBySource(SongSource source, String sourceId) async {
    final rows = await _db.query(
      'songs',
      where: 'source = ? AND source_id = ?',
      whereArgs: [source.name, sourceId],
    );
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  /// Canciones descargadas, las más recientes primero.
  Future<List<Song>> downloaded() async {
    final rows = await _db.query(
      'songs',
      where: 'local_path IS NOT NULL',
      orderBy: 'downloaded_at DESC',
    );
    return rows.map(Song.fromMap).toList();
  }

  /// Espacio total ocupado por las descargas, en bytes.
  Future<int> downloadedBytes() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(file_size_bytes), 0) AS total FROM songs '
      'WHERE local_path IS NOT NULL',
    );
    return rows.first['total']! as int;
  }

  Future<Song> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
  }) async {
    await _db.update(
      'songs',
      {
        'local_path': localPath,
        'file_size_bytes': sizeBytes,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
    return (await findById(id))!;
  }

  Future<void> clearDownload(String id) async {
    await _db.update(
      'songs',
      {'local_path': null, 'file_size_bytes': null, 'downloaded_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
