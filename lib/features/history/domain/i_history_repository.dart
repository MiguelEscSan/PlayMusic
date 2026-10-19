import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';

/// Historial de escucha. Nunca lanza: un fallo de la BD llega como `Err`.
abstract interface class IHistoryRepository {
  /// Canciones distintas, la escuchada más recientemente primero.
  Future<Result<List<Song>>> recentSongs();

  /// Más escuchadas de los últimos 30 días.
  Future<Result<List<Song>>> topSongs();

  /// Apunta una escucha de [song] ahora. Una canción sin id (aún no
  /// guardada) se ignora.
  Future<Result<Unit>> record(Song song);

  /// Borra todo el historial.
  Future<Result<Unit>> clear();
}
