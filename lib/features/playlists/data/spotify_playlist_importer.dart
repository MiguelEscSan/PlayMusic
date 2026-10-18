import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/i_playlist_importer.dart';
import '../domain/i_spotify_playlist_source.dart';
import '../domain/i_track_matcher.dart';
import '../domain/remote_playlist.dart';
import '../domain/spotify_playlist_link.dart';

/// Crea una playlist local a partir de una pública de Spotify: lee sus
/// pistas con [ISpotifyPlaylistSource] y busca cada una con
/// [ITrackMatcher]. Las pistas sin coincidencia fiable se omiten.
///
/// Primero empareja todas (lo lento, con progreso) y solo después crea la
/// playlist: si no se encuentra nada no queda una playlist vacía.
class SpotifyPlaylistImporter implements IPlaylistImporter {
  SpotifyPlaylistImporter(
    this._playlists,
    this._source,
    this._matcher, {
    this.concurrency = 4,
    this.matchTimeout = const Duration(seconds: 30),
  });

  final IPlaylistRepository _playlists;
  final ISpotifyPlaylistSource _source;
  final ITrackMatcher _matcher;

  /// Búsquedas a la vez: acelera las playlists largas sin saturar YouTube.
  final int concurrency;

  /// Tiempo máximo por búsqueda: una petición colgada no bloquea la
  /// importación; esa pista se omite.
  final Duration matchTimeout;

  /// Nunca lanza:
  /// - `Err(InvalidPlaylistLinkFailure)` si no es una playlist de Spotify.
  /// - El `Err` del origen (`NetworkFailure`, `NotFoundFailure`) si no se
  ///   puede leer.
  /// - `Err(NetworkFailure)` si fallaron todas las búsquedas.
  /// - `Err(EmptyPlaylistFailure)` si no hay pistas o ninguna coincide.
  /// En esos casos no se crea ninguna playlist. Un fallo al guardar llega
  /// como su `Err` (la playlist puede quedar a medias).
  @override
  Future<Result<ImportResult>> importFromUrl(
    String urlOrId, {
    ImportProgress? onProgress,
  }) async {
    final id = parseSpotifyPlaylistId(urlOrId);
    if (id == null) {
      return const Err(
        InvalidPlaylistLinkFailure(
          'El enlace no es de una playlist de Spotify',
        ),
      );
    }

    final RemotePlaylist remote;
    switch (await _source.fetch(id)) {
      case Ok(:final value):
        remote = value;
      case Err(:final failure):
        return Err(failure);
    }
    final tracks = remote.tracks;
    if (tracks.isEmpty) return const Err(EmptyPlaylistFailure());

    final matches = await _matchAll(tracks, onProgress);
    final songs = matches.whereType<Song>().toList();
    if (songs.isEmpty) {
      return matches.every((m) => m is Failure)
          ? Err(matches.first as Failure)
          : const Err(EmptyPlaylistFailure());
    }

    final name = remote.name.trim().isEmpty
        ? 'Playlist de Spotify'
        : remote.name.trim();
    final String playlistId;
    switch (await _playlists.create(name)) {
      case Ok(:final value):
        playlistId = value.id;
      case Err(:final failure):
        return Err(failure);
    }
    var imported = 0;
    for (final song in songs) {
      switch (await _playlists.addSong(playlistId, song)) {
        case Ok(value: true):
          imported++;
        case Ok(value: false):
          break; // Repetida.
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(
      ImportResult(
        playlistId: playlistId,
        imported: imported,
        skipped: tracks.length - imported,
        remoteTotal: remote.totalCount,
      ),
    );
  }

  /// Empareja cada pista, [concurrency] a la vez, conservando el orden.
  /// Cada posición es la canción, null (sin coincidencia) o el [Failure] de
  /// la búsqueda.
  Future<List<Object?>> _matchAll(
    List<RemoteTrack> tracks,
    ImportProgress? onProgress,
  ) async {
    final results = List<Object?>.filled(tracks.length, null);
    var next = 0;
    var done = 0;
    onProgress?.call(0, tracks.length);

    Future<void> worker() async {
      while (next < tracks.length) {
        final i = next++;
        results[i] = await _matchOne(tracks[i]);
        onProgress?.call(++done, tracks.length);
      }
    }

    await Future.wait([
      for (var w = 0; w < concurrency.clamp(1, tracks.length); w++) worker(),
    ]);
    return results;
  }

  Future<Object?> _matchOne(RemoteTrack track) async {
    try {
      return switch (await _matcher.match(track).timeout(matchTimeout)) {
        Ok(:final value) => value,
        Err(:final failure) => failure,
      };
    } catch (e, st) {
      return NetworkFailure(
        'No se pudo buscar la canción',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
