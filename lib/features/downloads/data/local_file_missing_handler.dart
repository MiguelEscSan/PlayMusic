import 'package:flutter/foundation.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_song_repository.dart';
import '../../../core/error/result.dart';
import 'download_manager.dart';

/// Lo que hace el resolver cuando el archivo local de una canción ya no
/// existe: olvidar la descarga para que se reproduzca en streaming.
///
/// El resolver se crea antes que el [DownloadManager] (que lo necesita), y
/// el reproductor ya resuelve canciones mientras arranca (p. ej. al
/// restaurar la última cola). Hasta que se asigna [manager] se limpia la BD
/// directamente; después se delega en él para que además avise a las listas
/// (`downloadsChanged`).
///
/// Nunca lanza: si no se puede olvidar se registra y se sigue en streaming.
class LocalFileMissingHandler {
  LocalFileMissingHandler(this._songRepository, {void Function(String)? log})
    : _log = log ?? _debugLog;

  final ISongRepository _songRepository;
  final void Function(String message) _log;

  /// Se asigna en cuanto existe; antes, el arranque del audio.
  DownloadManager? manager;

  static void _debugLog(String message) => debugPrint(message);

  Future<void> call(Song song) async {
    final manager = this.manager;
    final result = manager != null
        ? await manager.forgetMissingFile(song)
        : await _songRepository.clearDownload(song.id);
    if (result case Err(:final failure)) {
      _log('No se pudo olvidar el archivo perdido: $failure');
    }
  }
}
