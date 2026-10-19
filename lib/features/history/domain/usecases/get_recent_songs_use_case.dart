import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/domain/i_history_repository.dart';

/// Lo escuchado recientemente, lo último primero.
final class GetRecentSongsUseCase {
  const GetRecentSongsUseCase(this._history);

  final IHistoryRepository _history;

  Future<Result<List<Song>>> call() => _history.recentSongs();
}
