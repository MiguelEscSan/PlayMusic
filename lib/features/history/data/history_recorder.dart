import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../domain/history_events.dart';
import '../domain/i_history_repository.dart';

/// Apunta en el historial cada canción que empieza a sonar y, si se guardó,
/// lo anuncia en [HistoryEvents] para que Inicio se recargue.
///
/// Se crea una vez en `bootstrap()` y vive lo que vive la app.
class HistoryRecorder {
  HistoryRecorder({
    required AudioPlayerService audio,
    required this._history,
    required this._events,
  }) {
    _sub = audio.songStarted.listen((song) => unawaited(_record(song)));
  }

  final IHistoryRepository _history;
  final HistoryEvents _events;
  late final StreamSubscription<Song> _sub;

  Future<void> _record(Song song) async {
    // Las canciones de la cola ya están guardadas; por si acaso, una sin id
    // no se puede referenciar desde play_history.
    if (song.id.isEmpty) return;
    switch (await _history.record(song)) {
      case Ok():
        _events.announce();
      case Err(:final failure):
        // Que falle el historial no debe afectar a la reproducción.
        debugPrint('No se pudo guardar en el historial: $failure');
    }
  }

  Future<void> dispose() => _sub.cancel();
}
