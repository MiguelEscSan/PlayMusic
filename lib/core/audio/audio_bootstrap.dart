import 'package:audio_service/audio_service.dart';

import 'playback_source.dart';
import 'sponify_audio_handler.dart';

/// Arranca el servicio de audio en segundo plano. Llamar una sola vez en
/// `main()` antes de `runApp`.
Future<SponifyAudioHandler> initAudio(PlaybackSourceResolver resolver) {
  return AudioService.init(
    builder: () => SponifyAudioHandler(resolver: resolver),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sponify.sponify.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationChannelDescription: 'Controles de reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
