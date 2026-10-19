import 'package:koda/core/error/result.dart';
import 'package:koda/features/lyrics/domain/lyrics.dart';

/// Letras de canciones. Nunca lanza: un fallo del servicio (red, timeout,
/// error 5xx…) llega como `Err(NetworkFailure)` y no se cachea, para que
/// "Reintentar" vuelva a pedirla.
///
/// Recibe solo lo que el servicio necesita ([title], [artist]) y, opcional,
/// [durationSeconds] para afinar la coincidencia (0 = desconocida).
abstract interface class ILyricsRepository {
  Future<Result<Lyrics>> getLyrics(
    String title,
    String artist, {
    int durationSeconds = 0,
  });
}
