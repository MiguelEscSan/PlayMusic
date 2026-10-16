import 'package:sponify/core/data/models/playlist_model.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/data/repositories/guard.dart';
import 'package:sponify/core/domain/entities/playlist.dart' as domain;
import 'package:sponify/core/domain/entities/song.dart' as domain;
import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/database/playlist_dao.dart';

/// [IPlaylistRepository] sobre [PlaylistDao]: traduce entre las entidades de
/// dominio y [PlaylistModel]/[SongModel], y convierte toda excepción en un
/// `Err` vía [guard].
final class PlaylistRepositoryImpl implements IPlaylistRepository {
  PlaylistRepositoryImpl(this._dao);

  final PlaylistDao _dao;

  @override
  Future<Result<List<domain.Playlist>>> getAll() => guard(
    () async => [for (final model in await _dao.all()) model.toEntity()],
  );

  @override
  Future<Result<domain.Playlist>> findById(String id) async {
    final result = await guard(() => _dao.findById(id));
    return switch (result) {
      Ok(value: final model?) => Ok(model.toEntity()),
      Ok() => Err(NotFoundFailure('Playlist $id not found')),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<domain.Playlist>> create(String name, {String? description}) =>
      guard(
        () async =>
            (await _dao.create(name, description: description)).toEntity(),
      );

  @override
  Future<Result<Unit>> rename(String id, String name, {String? description}) =>
      guard(() async {
        await _dao.rename(id, name, description: description);
        return unit;
      });

  @override
  Future<Result<Unit>> setCover(String id, String? coverUrl) => guard(() async {
    await _dao.setCover(id, coverUrl);
    return unit;
  });

  @override
  Future<Result<Unit>> delete(String id) => guard(() async {
    await _dao.delete(id);
    return unit;
  });

  @override
  Future<Result<bool>> addSong(String playlistId, domain.Song song) =>
      guard(() => _dao.addSong(playlistId, SongModel.fromEntity(song)));

  @override
  Future<Result<bool>> removeSong(String playlistId, String songId) =>
      guard(() => _dao.removeSong(playlistId, songId));

  @override
  Future<Result<Unit>> removeSongAt(String playlistId, int index) =>
      guard(() async {
        await _dao.removeAt(playlistId, index);
        return unit;
      });

  @override
  Future<Result<Unit>> moveSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) => guard(() async {
    await _dao.move(playlistId, oldIndex, newIndex);
    return unit;
  });
}
