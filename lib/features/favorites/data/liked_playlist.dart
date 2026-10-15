import '../../../core/database/song_dao.dart';
import '../../../core/models/song.dart';
import '../../../core/settings/settings_dao.dart';
import '../../playlists/data/playlist_dao.dart';

/// Mantiene la playlist "Me encanta" igual que los "me gusta".
///
/// Es una playlist normal (se puede reproducir, reordenar o renombrar). Su id
/// se guarda en ajustes, así que renombrarla no la desconecta; si se borra,
/// se vuelve a crear con el siguiente "me gusta".
class LikedPlaylist {
  LikedPlaylist({
    required this._playlists,
    required this._songs,
    required this._settings,
  });

  static const name = 'Me encanta';

  final PlaylistDao _playlists;
  final SongDao _songs;
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
  Future<String> ensure() => _locked(_ensure);

  Future<String> _ensure() async {
    final id = await _settings.get(SettingsKeys.likedPlaylistId);
    if (id != null && await _playlists.findById(id) != null) return id;

    final playlist = await _playlists.create(name);
    await _settings.set(SettingsKeys.likedPlaylistId, playlist.id);
    for (final song in (await _songs.liked()).reversed) {
      await _playlists.addSong(playlist.id, song);
    }
    return playlist.id;
  }

  /// Añade o quita [song] según su `isLiked` (ya guardada en la BD).
  Future<void> sync(Song song) => _locked(() async {
    final id = await _ensure();
    if (song.isLiked) {
      await _playlists.addSong(id, song);
    } else {
      await _playlists.removeSong(id, song.id);
    }
  });
}
