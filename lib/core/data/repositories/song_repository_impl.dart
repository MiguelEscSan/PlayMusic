import 'package:koda/core/data/models/song_model.dart';
import 'package:koda/core/data/repositories/guard.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart' as domain;
import 'package:koda/core/domain/repositories/i_song_repository.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';

/// [ISongRepository] sobre [SongDao]: traduce entre la entidad de dominio y
/// [SongModel], y convierte toda excepción en un `Err` vía [guard].
final class SongRepositoryImpl implements ISongRepository {
  SongRepositoryImpl(this._dao);

  final SongDao _dao;

  @override
  Future<Result<domain.Song>> save(domain.Song song) => guard(
    () async => (await _dao.upsert(SongModel.fromEntity(song))).toEntity(),
  );

  @override
  Future<Result<domain.Song>> findById(String id) async {
    final result = await guard(() => _dao.findById(id));
    return switch (result) {
      Ok(value: final model?) => Ok(model.toEntity()),
      Ok() => Err(NotFoundFailure('Song $id not found')),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<domain.Song>> findBySource(
    domain.SongSource source,
    String sourceId,
  ) async {
    final result = await guard(() => _dao.findBySource(source, sourceId));
    return switch (result) {
      Ok(value: final model?) => Ok(model.toEntity()),
      Ok() => Err(NotFoundFailure('Song ${source.name}:$sourceId not found')),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<domain.Song>> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
  }) async {
    final result = await guard(
      () => _dao.markDownloaded(id, localPath: localPath, sizeBytes: sizeBytes),
    );
    return switch (result) {
      Ok(value: final model?) => Ok(model.toEntity()),
      Ok() => Err(NotFoundFailure('Song $id not found')),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<List<domain.Song>>> getDownloaded() =>
      guard(() async => _toEntities(await _dao.downloaded()));

  @override
  Future<Result<int>> getDownloadedBytes() => guard(_dao.downloadedBytes);

  @override
  Future<Result<List<domain.Song>>> getLiked() =>
      guard(() async => _toEntities(await _dao.liked()));

  @override
  Future<Result<Unit>> setLiked(String songId, {required bool liked}) =>
      guard(() async {
        await _dao.setLiked(songId, liked);
        return unit;
      });

  @override
  Future<Result<Unit>> clearDownload(String songId) => guard(() async {
    await _dao.clearDownload(songId);
    return unit;
  });

  static List<domain.Song> _toEntities(List<SongModel> models) => [
    for (final model in models) model.toEntity(),
  ];
}
