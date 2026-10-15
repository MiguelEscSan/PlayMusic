import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/song.dart';
import 'lrc_parser.dart';

/// Resultado de buscar la letra de una canción.
@immutable
sealed class Lyrics {
  const Lyrics();
}

/// Letra con marcas de tiempo (karaoke).
class SyncedLyrics extends Lyrics {
  const SyncedLyrics(this.lines);
  final List<LyricLine> lines;
}

/// Letra sin sincronizar.
class PlainLyrics extends Lyrics {
  const PlainLyrics(this.text);
  final String text;
}

class InstrumentalLyrics extends Lyrics {
  const InstrumentalLyrics();
}

class LyricsNotFound extends Lyrics {
  const LyricsNotFound();
}

/// Fallo al consultar el servicio (red, timeout, error 5xx…). No se cachea:
/// la UI ofrece "Reintentar".
class LyricsLoadException implements Exception {
  const LyricsLoadException(this.message);
  final String message;

  @override
  String toString() => 'LyricsLoadException: $message';
}

/// Obtiene letras de LRCLIB (https://lrclib.net), API pública sin clave.
///
/// Estrategia: `/api/get` con título, artista y duración exactos; si da 404,
/// `/api/search` y nos quedamos con el resultado de duración más cercana
/// (±5 s). Los resultados se cachean en memoria por canción.
class LyricsRepository {
  LyricsRepository({required this.dio});

  static const _baseUrl = 'https://lrclib.net/api';
  static const _userAgent =
      'Koda/1.0 (https://github.com/MiguelEscSan/PlayMusic)';

  /// Margen de duración aceptado al elegir un resultado de búsqueda.
  static const _durationTolerance = 5;

  final Dio dio;
  final _cache = <String, Lyrics>{};

  Future<Lyrics> getLyrics(Song song) async {
    final key = '${song.source.name}:${song.sourceId}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final lyrics = await _fetch(song);
    _cache[key] = lyrics;
    return lyrics;
  }

  Future<Lyrics> _fetch(Song song) async {
    final seconds = song.duration.inSeconds;
    final exact = await _request('/get', {
      'track_name': song.title,
      'artist_name': song.artist,
      if (seconds > 0) 'duration': '$seconds',
    });
    if (exact is Map<String, dynamic>) return _fromJson(exact);

    final results = await _request('/search', {
      'track_name': song.title,
      'artist_name': song.artist,
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
        throw LyricsLoadException('HTTP ${response.statusCode}');
      }
      return response.data;
    } on DioException catch (e) {
      throw LyricsLoadException(e.message ?? e.type.name);
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
