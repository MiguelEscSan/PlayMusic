import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../di/providers.dart';

/// Estado del reproductor para la UI (mini-player, pantalla Now Playing).
final playerSnapshotProvider = StreamProvider<PlayerSnapshot>(
  (ref) => ref.watch(watchPlayerSnapshotUseCaseProvider)(),
);

/// Posición de reproducción, separada para no reconstruir toda la UI.
final playerPositionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(watchPlayerPositionUseCaseProvider)(),
);
