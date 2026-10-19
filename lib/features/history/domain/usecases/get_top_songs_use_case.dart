import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/domain/i_history_repository.dart';

/// Lo más escuchado de los últimos 30 días.
final class GetTopSongsUseCase {
  const GetTopSongsUseCase(this._history);

  final IHistoryRepository _history;

  Future<Result<List<Song>>> call() => _history.topSongs();
}
