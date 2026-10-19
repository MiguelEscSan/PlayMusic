import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/download_task.dart';

/// Contrato del gestor de descargas (cola, progreso, cancelación y
/// borrado de archivos). Las implementaciones tocan archivos y red, así que
/// pueden lanzar: los casos de uso convierten esas excepciones en `Err`.
abstract interface class IDownloadService {
  /// Todas las descargas en curso o recientes, por `songKey`; emite el
  /// estado actual al suscribirse y en cada cambio.
  Stream<Map<String, DownloadTask>> get tasksStream;

  /// Emite la canción (ya actualizada) cada vez que su archivo local
  /// aparece o desaparece. El progreso no emite aquí.
  Stream<Song> get downloadsChanged;

  /// Encola la descarga y devuelve la canción tal como quedó en la BD. Un
  /// fallo al guardar deja la tarea fallida y devuelve [song] tal cual.
  Future<Song> download(Song song);

  /// Cancela una descarga en cola o en curso y borra el archivo parcial.
  Future<void> cancel(Song song);

  /// Borra el archivo descargado; la canción sigue en sus playlists.
  Future<Result<Song>> delete(Song song);

  /// Borra todas las descargas. Se detiene en el primer fallo.
  Future<Result<Unit>> deleteAll();
}
