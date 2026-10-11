import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_service.dart';

/// Servicio de audio único de la app. Se crea en `main()` (AudioService.init
/// es asíncrono) y se inyecta con `overrideWithValue`.
final audioPlayerServiceProvider = Provider<AudioPlayerService>(
  (ref) => throw UnimplementedError(
    'audioPlayerServiceProvider debe sobrescribirse en main()',
  ),
);

/// Estado del reproductor para la UI (mini-player, pantalla Now Playing).
final playerSnapshotProvider = StreamProvider<PlayerSnapshot>(
  (ref) => ref.watch(audioPlayerServiceProvider).snapshots,
);

/// Posición de reproducción, separada para no reconstruir toda la UI.
final playerPositionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioPlayerServiceProvider).positionStream,
);
