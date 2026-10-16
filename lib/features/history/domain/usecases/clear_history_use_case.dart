import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/history/domain/history_events.dart';
import 'package:sponify/features/history/domain/i_history_repository.dart';

/// Borra el historial de escucha y, si lo consigue, lo anuncia para que
/// las listas de Inicio se vacíen.
final class ClearHistoryUseCase {
  const ClearHistoryUseCase(this._history, this._events);

  final IHistoryRepository _history;
  final HistoryEvents _events;

  Future<Result<Unit>> call() async {
    final result = await _history.clear();
    if (result.isOk) _events.announce();
    return result;
  }
}
