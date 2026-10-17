import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/i_lyrics_repository.dart';
import '../domain/lyrics.dart';
import 'lrc_parser.dart';

/// Fallo al consultar el servicio (red, timeout, error 5xx…). Solo vive
/// dentro de la capa de datos: [LyricsRepositoryImpl.getLyrics] lo
/// devuelve como `Err(NetworkFailure)`.
class _LyricsLoadException implements Exception {
  const _LyricsLoadException(this.message);
  final String message;

  @override
  String toString() => 'LyricsLoadException: $message';
}

/// Obtiene letras de LRCLIB (https://lrclib.net), API pública sin clave.
///
/// Estrategia: `/api/get` con título, artista y duración exactos; si da 404,
/// `/api/search` y nos quedamos con el resultado de duración más cercana
/// (±5 s). Los resultados se cachean en memoria por canción; los fallos no
/// (la UI ofrece "Reintentar").
class LyricsRepositoryImpl implements ILyricsRepository {
  LyricsRepositoryImpl({required this.dio});

  static const _baseUrl = 'https://lrclib.net/api';
  static const _userAgent =
      'Koda/1.0 (https://github.com/MiguelEscSan/PlayMusic)';

  /// Margen de duración aceptado al elegir un resultado de búsqueda.
  static const _durationTolerance = 5;

  final Dio dio;
  final _cache = <String, Lyrics>{};

  @override
  Future<Result<Lyrics>> getLyrics(
    String title,
    String artist, {
    int durationSeconds = 0,
  }) async {
    final key = '$title\u0000$artist\u0000$durationSeconds';
    final cached = _cache[key];
    if (cached != null) return Ok(cached);

    try {
      final lyrics = await _fetch(title, artist, durationSeconds);
      _cache[key] = lyrics;
      return Ok(lyrics);
    } on _LyricsLoadException catch (e, st) {
      return Err(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on Exception catch (e, st) {
      return Err(UnexpectedFailure(e.toString(), cause: e, stackTrace: st));
    }
  }

  Future<Lyrics> _fetch(String title, String artist, int seconds) async {
    final exact = await _request('/get', {
      'track_name': title,
      'artist_name': artist,
      if (seconds > 0) 'duration': '$seconds',
    });
    if (exact is Map<String, dynamic>) return _fromJson(exact);

    final results = await _request('/search', {
      'track_name': title,
      'artist_name': artist,
    });
    if (results is! List) return const LyricsNotFound();

    Map<String, dynamic>? best;
    num? bestDiff;
    for (final item in results.whereType<Map<String, dynamic>>()) {
      final duration = item['duration'];
      if (seconds <= 0) {
        // Sin duración conocida: nos fiamos del primer resultado.
        best = item;
        break;
      }
      if (duration is! num) continue;
      final diff = (duration - seconds).abs();
      if (diff <= _durationTolerance && (bestDiff == null || diff < bestDiff)) {
        best = item;
        bestDiff = diff;
      }
    }
    return best == null ? const LyricsNotFound() : _fromJson(best);
  }

  /// Devuelve el JSON decodificado, o `null` si el servicio responde 404.
  Future<Object?> _request(String path, Map<String, String> query) async {
    try {
      final response = await dio.get<Object>(
        '$_baseUrl$path',
        queryParameters: query,
        options: Options(
          headers: {'User-Agent': _userAgent},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw _LyricsLoadException('HTTP ${response.statusCode}');
      }
      return response.data;
    } on DioException catch (e) {
      throw _LyricsLoadException(e.message ?? e.type.name);
    }
  }

  Lyrics _fromJson(Map<String, dynamic> json) {
    if (json['instrumental'] == true) return const InstrumentalLyrics();

    final synced = json['syncedLyrics'];
    if (synced is String && synced.trim().isNotEmpty) {
      final lines = parseLrc(synced);
      if (lines.isNotEmpty) return SyncedLyrics(lines);
    }

    final plain = json['plainLyrics'];
    if (plain is String && plain.trim().isNotEmpty) {
      return PlainLyrics(plain.trim());
    }
    return const LyricsNotFound();
  }
}
