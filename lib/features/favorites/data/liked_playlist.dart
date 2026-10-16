import '../../../core/domain/entities/playlist.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/domain/repositories/i_song_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/settings/settings_dao.dart';

/// Mantiene la playlist "Me encanta" igual que los "me gusta".
///
/// Es una playlist normal (se puede reproducir, reordenar o renombrar). Su id
/// se guarda en ajustes, así que renombrarla no la desconecta; si se borra,
/// se vuelve a crear con el siguiente "me gusta".
///
/// Nunca lanza por un fallo de los repositorios: lo devuelve como `Err`.
class LikedPlaylist {
  LikedPlaylist({
    required this._playlists,
    required this._songs,
    required this._settings,
  });

  static const name = 'Me encanta';

  final IPlaylistRepository _playlists;
  final ISongRepository _songs;
  final SettingsDao _settings;

  // Serializa las operaciones: dos "me gusta" seguidos no deben crear dos
  // playlists.
  Future<void> _last = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Id de la playlist. Si no existe la crea con todos los "me gusta"
  /// actuales, del más antiguo al más reciente.
  Future<Result<String>> ensure() => _locked(_ensure);

  Future<Result<String>> _ensure() async {
    final id = await _settings.get(SettingsKeys.likedPlaylistId);
    if (id != null) {
      switch (await _playlists.findById(id)) {
        case Ok():
          return Ok(id);
        case Err(failure: NotFoundFailure()):
          // Borrada: se vuelve a crear abajo.
          break;
        case Err(:final failure):
          return Err(failure);
      }
    }

    final Playlist playlist;
    switch (await _playlists.create(name)) {
      case Ok(:final value):
        playlist = value;
      case Err(:final failure):
        return Err(failure);
    }
    await _settings.set(SettingsKeys.likedPlaylistId, playlist.id);

    final List<Song> liked;
    switch (await _songs.getLiked()) {
      case Ok(:final value):
        liked = value;
      case Err(:final failure):
        return Err(failure);
    }
    for (final song in liked.reversed) {
      if (await _playlists.addSong(playlist.id, song) case Err(
        :final failure,
      )) {
        return Err(failure);
      }
    }
    return Ok(playlist.id);
  }

  /// Añade o quita [song] según su `isLiked` (ya guardada en la BD).
  Future<Result<Unit>> sync(Song song) => _locked(() async {
    switch (await _ensure()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final id):
        final result = song.isLiked
            ? await _playlists.addSong(id, song)
            : await _playlists.removeSong(id, song.id);
        return result.map((_) => unit);
    }
  });
}
