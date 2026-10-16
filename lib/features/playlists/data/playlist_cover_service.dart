import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';

/// Portadas personalizadas de las playlists.
///
/// La imagen elegida se copia a [_dir] (el original puede ser un archivo
/// temporal del selector de fotos) y su ruta se guarda en `cover_url`. Cada
/// copia lleva un nombre nuevo para que la caché de imágenes no muestre la
/// anterior, y el archivo viejo se borra al cambiarla o quitarla.
///
/// Un fallo del repositorio se devuelve como `Err` (no se lanza) y deja el
/// archivo anterior en su sitio.
class PlaylistCoverService {
  PlaylistCoverService(this._playlists, this._dir);

  final IPlaylistRepository _playlists;
  final Directory _dir;

  Future<Result<Unit>> setFromFile(String playlistId, String sourcePath) async {
    await _dir.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = p.join(_dir.path, '$playlistId-$stamp$extension');
    await File(sourcePath).copy(target);

    return _replace(playlistId, () => _playlists.setCover(playlistId, target));
  }

  Future<Result<Unit>> clear(String playlistId) =>
      _replace(playlistId, () => _playlists.setCover(playlistId, null));

  Future<Result<Unit>> deletePlaylist(String playlistId) =>
      _replace(playlistId, () => _playlists.delete(playlistId));

  /// Lee la portada actual, aplica [change] y, solo si sale bien, borra la
  /// portada anterior.
  Future<Result<Unit>> _replace(
    String playlistId,
    Future<Result<Unit>> Function() change,
  ) async {
    final String? old;
    switch (await _playlists.findById(playlistId)) {
      case Ok(:final value):
        old = value.coverUrl;
      case Err(failure: NotFoundFailure()):
        old = null;
      case Err(:final failure):
        return Err(failure);
    }
    if (await change() case Err(:final failure)) return Err(failure);
    await _deleteOwned(old);
    return const Ok(unit);
  }

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
