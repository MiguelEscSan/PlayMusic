import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';

/// Contrato de acceso a canciones persistidas. Las implementaciones nunca
/// lanzan: todo error se devuelve como `Err` con un `Failure`.
abstract interface class ISongRepository {
  /// Inserta o actualiza la canción. No modifica su estado de "me gusta".
  Future<Result<Song>> save(Song song);

  /// `Err(NotFoundFailure)` si no existe.
  Future<Result<Song>> findById(String id);

  /// Canciones con archivo local, de la más reciente a la más antigua.
  Future<Result<List<Song>>> getDownloaded();

  /// Suma en bytes de todos los archivos descargados.
  Future<Result<int>> getDownloadedBytes();

  /// Canciones marcadas con "me gusta".
  Future<Result<List<Song>>> getLiked();

  /// Marca o desmarca "me gusta" en la canción [songId].
  Future<Result<Unit>> setLiked(String songId, {required bool liked});

  /// Olvida el archivo local de la canción (ruta, tamaño y fecha).
  Future<Result<Unit>> clearDownload(String songId);
}
