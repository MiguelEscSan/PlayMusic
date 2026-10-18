import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/domain/sources/i_remote_playlist_source.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/i_playlist_importer.dart';

/// Crea una playlist local a partir de una de YouTube, con el mismo título y
/// las canciones en el mismo orden. La lectura de la playlist remota la hace
/// el [IRemotePlaylistSource].
class YoutubePlaylistImporter implements IPlaylistImporter {
  YoutubePlaylistImporter(this._playlists, this._source);

  /// Límite de canciones por importación, para no eternizarse.
  static const maxSongs = 500;

  final IPlaylistRepository _playlists;
  final IRemotePlaylistSource _source;

  /// Acepta el enlace completo o solo el id. Nunca lanza:
  /// `Err(InvalidPlaylistLinkFailure)` si no es válido,
  /// `Err(NetworkFailure)` si no se puede leer de YouTube y
  /// `Err(EmptyPlaylistFailure)` si no hay nada que importar; en esos casos
  /// no se crea ninguna playlist. Un fallo al guardar llega como su `Err`
  /// (la playlist puede quedar a medias, como antes).
  @override
  Future<Result<ImportResult>> importFromUrl(
    String urlOrId, {
    ImportProgress? onProgress,
  }) async {
    final id = _source.parsePlaylistId(urlOrId.trim());
    if (id == null) return const Err(InvalidPlaylistLinkFailure());

    final String title;
    final List<Song?> fetched;
    try {
      (title: title, songs: fetched) = await _source.fetch(
        id,
        maxSongs: maxSongs,
      );
    } catch (e, st) {
      return Err(
        NetworkFailure(
          'No se pudo leer la playlist de YouTube',
          cause: e,
          stackTrace: st,
        ),
      );
    }
    final videos = fetched.take(maxSongs).toList();
    if (videos.every((s) => s == null)) {
      return const Err(EmptyPlaylistFailure());
    }

    final name = title.trim().isEmpty ? 'Playlist de YouTube' : title;
    final String playlistId;
    switch (await _playlists.create(name)) {
      case Ok(:final value):
        playlistId = value.id;
      case Err(:final failure):
        return Err(failure);
    }
    var imported = 0;
    onProgress?.call(0, videos.length);
    for (var i = 0; i < videos.length; i++) {
      if (videos[i] case final song?) {
        switch (await _playlists.addSong(playlistId, song)) {
          case Ok(value: true):
            imported++;
          case Ok(value: false):
            break; // Repetida.
          case Err(:final failure):
            return Err(failure);
        }
      }
      onProgress?.call(i + 1, videos.length);
    }
    return Ok(
      ImportResult(
        playlistId: playlistId,
        imported: imported,
        skipped: videos.length - imported,
      ),
    );
  }
}
