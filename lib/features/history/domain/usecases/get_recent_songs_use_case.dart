import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/history/domain/i_history_repository.dart';

/// Lo escuchado recientemente, lo último primero.
final class GetRecentSongsUseCase {
  const GetRecentSongsUseCase(this._history);

  final IHistoryRepository _history;

  Future<Result<List<Song>>> call() => _history.recentSongs();
}
