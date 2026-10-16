import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/domain/entities/song.dart';
import 'history_dao.dart';

/// Apunta en el historial cada canción que empieza a sonar.
///
/// Se crea una vez en `bootstrap()` y vive lo que vive la app.
class HistoryRecorder {
  HistoryRecorder({
    required AudioPlayerService audio,
    required HistoryDao dao,
  }) {
    _sub = audio.songStarted.listen((song) => unawaited(_record(dao, song)));
  }

  late final StreamSubscription<Song> _sub;

  static Future<void> _record(HistoryDao dao, Song song) async {
    // Las canciones de la cola ya están guardadas; por si acaso, una sin id
    // no se puede referenciar desde play_history.
    if (song.id.isEmpty) return;
    try {
      await dao.record(song.id);
    } catch (e) {
      // Que falle el historial no debe afectar a la reproducción.
      debugPrint('No se pudo guardar en el historial: $e');
    }
  }

  Future<void> dispose() => _sub.cancel();
}
