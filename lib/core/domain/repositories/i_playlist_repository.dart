import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';

/// Contrato de acceso a playlists. Las implementaciones nunca lanzan: todo
/// error se devuelve como `Err` con un `Failure`.
abstract interface class IPlaylistRepository {
  Future<Result<List<Playlist>>> getAll();

  /// `Err(NotFoundFailure)` si no existe.
  Future<Result<Playlist>> findById(String id);

  Future<Result<Playlist>> create(String name, {String? description});

  Future<Result<Unit>> rename(String id, String name, {String? description});

  Future<Result<Unit>> delete(String id);

  /// Añade [song] al final. `Ok(false)` si ya estaba en la playlist.
  Future<Result<bool>> addSong(String playlistId, Song song);

  /// Quita la canción [songId]. `Ok(false)` si no estaba en la playlist.
  Future<Result<bool>> removeSong(String playlistId, String songId);

  /// Mueve una canción (semántica de `ReorderableListView`).
  Future<Result<Unit>> moveSong(String playlistId, int oldIndex, int newIndex);
}
