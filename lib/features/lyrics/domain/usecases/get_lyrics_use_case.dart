import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/lyrics/domain/i_lyrics_repository.dart';
import 'package:sponify/features/lyrics/domain/lyrics.dart';

/// Letra de [song]. Un fallo del servicio llega como `Err`.
final class GetLyricsUseCase {
  const GetLyricsUseCase(this._lyrics);

  final ILyricsRepository _lyrics;

  Future<Result<Lyrics>> call(Song song) => guardResult(
    () => _lyrics.getLyrics(
      song.title,
      song.artist,
      durationSeconds: song.duration.inSeconds,
    ),
    onError: (e, st) => UnexpectedFailure(
      'No se pudo cargar la letra',
      cause: e,
      stackTrace: st,
    ),
  );
}
