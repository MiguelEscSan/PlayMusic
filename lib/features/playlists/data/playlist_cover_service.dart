import 'dart:io';

import 'package:path/path.dart' as p;

import 'playlist_dao.dart';

/// Portadas personalizadas de las playlists.
///
/// La imagen elegida se copia a [_dir] (el original puede ser un archivo
/// temporal del selector de fotos) y su ruta se guarda en `cover_url`. Cada
/// copia lleva un nombre nuevo para que la caché de imágenes no muestre la
/// anterior, y el archivo viejo se borra al cambiarla o quitarla.
class PlaylistCoverService {
  PlaylistCoverService(this._dao, this._dir);

  final PlaylistDao _dao;
  final Directory _dir;

  Future<void> setFromFile(String playlistId, String sourcePath) async {
    await _dir.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = p.join(_dir.path, '$playlistId-$stamp$extension');
    await File(sourcePath).copy(target);

    final old = await _currentCover(playlistId);
    await _dao.setCover(playlistId, target);
    await _deleteOwned(old);
  }

  Future<void> clear(String playlistId) async {
    final old = await _currentCover(playlistId);
    await _dao.setCover(playlistId, null);
    await _deleteOwned(old);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final old = await _currentCover(playlistId);
    await _dao.delete(playlistId);
    await _deleteOwned(old);
  }

  Future<String?> _currentCover(String playlistId) async =>
      (await _dao.findById(playlistId))?.coverUrl;

  /// Solo borra archivos que creó este servicio.
  Future<void> _deleteOwned(String? path) async {
    if (path == null || !p.isWithin(_dir.path, path)) return;
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Ya no estaba.
    }
  }
}
