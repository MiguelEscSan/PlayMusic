import 'package:koda/core/error/result.dart';
import 'package:koda/features/history/domain/history_events.dart';

/// Avisa cada vez que el historial cambia (una escucha guardada o el
/// historial borrado). Las listas de Inicio se recargan con él.
final class WatchHistoryChangedUseCase {
  const WatchHistoryChangedUseCase(this._events);

  final HistoryEvents _events;

  Stream<Unit> call() => _events.changes;
}
