import 'package:sponify/core/audio/audio_player_service.dart';

/// Siguiente modo de repetición al pulsar el botón: off → todo → una → off.
PlayerRepeatMode nextRepeatMode(PlayerRepeatMode mode) => switch (mode) {
  PlayerRepeatMode.off => PlayerRepeatMode.all,
  PlayerRepeatMode.all => PlayerRepeatMode.one,
  PlayerRepeatMode.one => PlayerRepeatMode.off,
};

/// Índice de la canción anterior de la cola (sin dar la vuelta), o `null`
/// si no hay anterior. Deslizar hacia atrás siempre va a ella; el botón ⏮
/// usa en cambio `skipToPrevious`, que reinicia la canción tras 3 s.
int? previousSongIndex(PlayerSnapshot snapshot) =>
    snapshot.hasPrevious ? snapshot.currentIndex! - 1 : null;
