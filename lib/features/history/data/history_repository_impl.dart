import 'package:koda/core/data/repositories/guard.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/data/history_dao.dart';
import 'package:koda/features/history/domain/i_history_repository.dart';

/// [IHistoryRepository] sobre la tabla `play_history` ([HistoryDao]):
/// convierte los `SongModel` en entidades y los fallos en `Err`.
class HistoryRepositoryImpl implements IHistoryRepository {
  HistoryRepositoryImpl(this._dao);

  final HistoryDao _dao;

  @override
  Future<Result<List<Song>>> recentSongs() => guard(
    () async => [for (final model in await _dao.recent()) model.toEntity()],
  );

  @override
  Future<Result<List<Song>>> topSongs() => guard(
    () async => [for (final model in await _dao.topSongs()) model.toEntity()],
  );

  @override
  Future<Result<Unit>> record(Song song) => guard(() async {
    // Sin id no se puede referenciar desde play_history.
    if (song.id.isNotEmpty) await _dao.record(song.id);
    return unit;
  });

  @override
  Future<Result<Unit>> clear() => guard(() async {
    await _dao.clear();
    return unit;
  });
}
