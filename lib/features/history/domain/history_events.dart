import 'dart:async';

import 'package:koda/core/error/result.dart';

/// Aviso de que el historial cambió: lo anuncian quienes lo escriben (el
/// `HistoryRecorder` tras guardar una escucha, `ClearHistoryUseCase` tras
/// borrarlo) y lo escuchan las listas de Inicio para recargarse.
///
/// Sustituye al antiguo `HistoryDao.changes`: el DAO solo lee y escribe.
class HistoryEvents {
  final _changes = StreamController<Unit>.broadcast();

  Stream<Unit> get changes => _changes.stream;

  void announce() {
    if (!_changes.isClosed) _changes.add(unit);
  }

  Future<void> dispose() => _changes.close();
}
