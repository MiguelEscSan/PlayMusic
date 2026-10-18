import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/i_spotify_playlist_source.dart';
import '../domain/remote_playlist.dart';
import 'spotify_page_parser.dart';

/// Lee playlists públicas de Spotify sin iniciar sesión, con dos páginas
/// públicas:
/// - `open.spotify.com/embed/playlist/<id>`: nombre y hasta 100 pistas.
/// - `open.spotify.com/playlist/<id>` pedida como rastreador: el total real.
///   Si falla, el total queda en null y la importación sigue.
///
/// Nunca usa el token del reproductor web ni ningún login.
class SpotifyEmbedPlaylistSource implements ISpotifyPlaylistSource {
  SpotifyEmbedPlaylistSource(
    this._dio, {
    this.retryDelay = const Duration(milliseconds: 600),
  });

  /// Cliente con tiempos de espera razonables para la app.
  factory SpotifyEmbedPlaylistSource.create() => SpotifyEmbedPlaylistSource(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    ),
  );

  final Dio _dio;

  /// Espera antes del primer reintento; se dobla en cada uno.
  final Duration retryDelay;

  /// Intentos por página: la primera petición al embed llegó a dar 504 y
  /// el reintento funcionó.
  static const maxAttempts = 3;

  static const _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// Con un navegador normal la página pública llega vacía; a los
  /// rastreadores de enlaces se les sirve con las metas.
  static const _crawlerUserAgent = 'facebookexternalhit/1.1';

  @override
  Future<Result<RemotePlaylist>> fetch(String playlistId) async {
    final RemotePlaylist playlist;
    try {
      final html = await _get(
        'https://open.spotify.com/embed/playlist/$playlistId',
        _browserUserAgent,
      );
      playlist = parseSpotifyEmbed(html);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        return Err(
          NotFoundFailure(
            'La playlist de Spotify no existe o no es pública',
            cause: e,
            stackTrace: st,
          ),
        );
      }
      return Err(
        NetworkFailure(
          'No se pudo leer la playlist de Spotify',
          cause: e,
          stackTrace: st,
        ),
      );
    } on FormatException catch (e, st) {
      return Err(
        NetworkFailure(
          'La página de Spotify ha cambiado de formato',
          cause: e,
          stackTrace: st,
        ),
      );
    }
    return Ok(playlist.copyWith(totalCount: await _totalCount(playlistId)));
  }

  /// El total real de pistas, o null si no se puede saber: nunca falla.
  Future<int?> _totalCount(String playlistId) async {
    try {
      return parseSpotifyTotalCount(
        await _get(
          'https://open.spotify.com/playlist/$playlistId',
          _crawlerUserAgent,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// GET con reintentos ante errores 5xx y fallos de red o de tiempo.
  Future<String> _get(String url, String userAgent) async {
    var delay = retryDelay;
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent': userAgent,
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
            },
          ),
        );
        return response.data ?? '';
      } on DioException catch (e) {
        if (attempt >= maxAttempts || !_isTransient(e)) rethrow;
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
  }

  static bool _isTransient(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => (e.response?.statusCode ?? 0) >= 500,
    DioExceptionType.unknown => e.error is! FormatException,
    _ => false,
  };
}
