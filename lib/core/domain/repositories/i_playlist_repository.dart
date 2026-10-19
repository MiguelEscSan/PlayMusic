import 'package:koda/core/domain/entities/playlist.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';

/// Contrato de acceso a playlists. Las implementaciones nunca lanzan: todo
/// error se devuelve como `Err` con un `Failure`.
abstract interface class IPlaylistRepository {
  Future<Result<List<Playlist>>> getAll();

  /// `Err(NotFoundFailure)` si no existe.
  Future<Result<Playlist>> findById(String id);

  Future<Result<Playlist>> create(String name, {String? description});

  Future<Result<Unit>> rename(String id, String name, {String? description});

  /// Portada personalizada (ruta local); `null` vuelve a la automática.
  Future<Result<Unit>> setCover(String id, String? coverUrl);

  Future<Result<Unit>> delete(String id);

  /// Añade [song] al final. `Ok(false)` si ya estaba en la playlist.
  Future<Result<bool>> addSong(String playlistId, Song song);

  /// Quita la canción [songId]. `Ok(false)` si no estaba en la playlist.
  Future<Result<bool>> removeSong(String playlistId, String songId);

  /// Quita la canción que ocupa la posición [index].
  Future<Result<Unit>> removeSongAt(String playlistId, int index);

  /// Mueve la canción de [oldIndex] a [newIndex], que es la posición final
  /// ya corregida (no la semántica de hueco de `ReorderableListView`).
  Future<Result<Unit>> moveSong(String playlistId, int oldIndex, int newIndex);
}
