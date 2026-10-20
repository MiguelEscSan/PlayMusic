import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_song_repository.dart';
import '../../../core/error/result.dart';

/// Corrige la duración guardada de una canción cuando el reproductor reporta
/// otra distinta: la metadata de búsqueda puede no coincidir con el audio.
///
/// Se guarda una sola vez por canción y sesión.
class SongDurationCorrector {
  SongDurationCorrector({
    required AudioPlayerService audio,
    required this._songs,
  }) {
    _sub = audio.snapshots.listen(_onSnapshot);
  }

  static const _tolerance = Duration(seconds: 2);

  final ISongRepository _songs;
  late final StreamSubscription<PlayerSnapshot> _sub;
  final _corrected = <String>{};

  void _onSnapshot(PlayerSnapshot snapshot) {
    final song = snapshot.currentSong;
    final real = snapshot.duration;
    if (song == null || real == null || real <= Duration.zero) return;
    if (_corrected.contains(song.id)) return;
    if ((real - song.duration).abs() <= _tolerance) return;

    _corrected.add(song.id);
    unawaited(_save(song.copyWith(durationMs: real.inMilliseconds)));
  }

  Future<void> _save(Song song) async {
    switch (await _songs.save(song)) {
      case Ok():
        break;
      case Err(:final failure):
        // Una duración mal guardada no debe afectar a la reproducción.
        debugPrint('No se pudo corregir la duración: $failure');
    }
  }

  Future<void> dispose() => _sub.cancel();
}
