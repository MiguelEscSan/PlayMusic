import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/domain/entities/last_playback.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_settings_repository.dart';
import '../../../core/domain/repositories/i_song_repository.dart';
import '../../../core/error/result.dart';

/// Guarda cola, canción y posición cada vez que cambia el estado y cada pocos
/// segundos mientras suena, para retomarlo al abrir la app.
///
/// Se crea una vez en `bootstrap()` y vive lo que vive la app.
class LastPlaybackRecorder {
  LastPlaybackRecorder({
    required AudioPlayerService audio,
    required this._settings,
  }) : _audio = audio {
    _subs
      ..add(audio.snapshots.listen((snapshot) => _save(snapshot)))
      ..add(audio.positionStream.listen((position) => _position = position));
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _save(_audio.current),
    );
  }

  final AudioPlayerService _audio;
  final ISettingsRepository _settings;
  final _subs = <StreamSubscription<Object?>>[];
  late final Timer _timer;
  Duration _position = Duration.zero;

  Future<void> _save(PlayerSnapshot snapshot) async {
    final index = snapshot.currentIndex;
    if (index == null || snapshot.queue.isEmpty) return;
    final playback = LastPlayback(
      songIds: [for (final song in snapshot.queue) song.id],
      index: index,
      position: _position,
    );
    switch (await _settings.setLastPlayback(playback)) {
      case Ok():
        break;
      case Err(:final failure):
        // Que falle el guardado no debe afectar a la reproducción.
        debugPrint('No se pudo guardar la última reproducción: $failure');
    }
  }

  void dispose() {
    _timer.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
  }
}

/// Retoma la última reproducción guardada, en pausa y en su posición. Si una
/// canción se borró desde entonces, se omite y la posición se ignora.
Future<void> restoreLastPlayback({
  required ISettingsRepository settings,
  required ISongRepository songs,
  required Future<void> Function(
    List<Song> songs, {
    required int index,
    required Duration position,
  })
  restore,
}) async {
  final saved = switch (await settings.getLastPlayback()) {
    Ok(value: final value) => value,
    Err() => null,
  };
  if (saved == null || saved.songIds.isEmpty) return;

  final found = <Song>[];
  var index = 0;
  var savedSongFound = false;
  for (var i = 0; i < saved.songIds.length; i++) {
    switch (await songs.findById(saved.songIds[i])) {
      case Ok(value: final song):
        if (i == saved.index) {
          index = found.length;
          savedSongFound = true;
        }
        found.add(song);
      case Err():
        break;
    }
  }
  if (found.isEmpty) return;

  await restore(
    found,
    index: index,
    position: savedSongFound ? saved.position : Duration.zero,
  );
}
