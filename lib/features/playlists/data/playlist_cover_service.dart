import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/i_playlist_cover_service.dart';

/// Portadas personalizadas de las playlists.
///
/// La imagen elegida se copia a [_dir] (el original puede ser un archivo
/// temporal del selector de fotos) y su ruta se guarda en `cover_url`. Cada
/// copia lleva un nombre nuevo para que la caché de imágenes no muestre la
/// anterior, y el archivo viejo se borra al cambiarla o quitarla.
///
/// Nunca lanza. Un fallo del repositorio se devuelve como `Err`, deja el
/// archivo anterior en su sitio y descarta la copia nueva. Si no se puede
/// copiar la imagen, `Err(StorageFailure)` sin tocar la BD. Un fallo al
/// borrar un archivo viejo no deshace el cambio ya guardado: se ignora.
class PlaylistCoverService implements IPlaylistCoverService {
  PlaylistCoverService(this._playlists, this._dir);

  final IPlaylistRepository _playlists;
  final Directory _dir;

  @override
  Future<Result<Unit>> setFromFile(String playlistId, String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = p.join(_dir.path, '$playlistId-$stamp$extension');
    try {
      await _dir.create(recursive: true);
      await File(sourcePath).copy(target);
    } on FileSystemException catch (e, st) {
      await _deleteOwned(target);
      return Err(
        StorageFailure(
          'No se pudo copiar la portada',
          cause: e,
          stackTrace: st,
        ),
      );
    }

    final result = await _replace(
      playlistId,
      () => _playlists.setCover(playlistId, target),
    );
    // La copia nueva no llegó a guardarse: se borra (nunca el original).
    if (result.isErr) await _deleteOwned(target);
    return result;
  }

  @override
  Future<Result<Unit>> clear(String playlistId) =>
      _replace(playlistId, () => _playlists.setCover(playlistId, null));

  @override
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

  /// Solo borra archivos que creó este servicio. Si no se puede borrar
  /// (ya no estaba, o el sistema lo impide) queda huérfano: no es un error
  /// para quien llama.
  Future<void> _deleteOwned(String? path) async {
    if (path == null || !p.isWithin(_dir.path, path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Ya no estaba o no se pudo borrar.
    }
  }
}
