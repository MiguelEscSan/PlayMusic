import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/lyrics/domain/lyrics.dart';

/// Letras de canciones. Nunca lanza: un fallo del servicio (red, timeout,
/// error 5xx…) llega como `Err(NetworkFailure)` y no se cachea, para que
/// "Reintentar" vuelva a pedirla.
abstract interface class ILyricsRepository {
  Future<Result<Lyrics>> getLyrics(Song song);
}
