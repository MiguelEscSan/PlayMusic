import 'package:audio_service/audio_service.dart';

import 'playback_source.dart';
import 'koda_audio_handler.dart';

/// Arranca el servicio de audio en segundo plano. Llamar una sola vez en
/// `main()` antes de `runApp`.
Future<KodaAudioHandler> initAudio(PlaybackSourceResolver resolver) {
  return AudioService.init(
    builder: () => KodaAudioHandler(resolver: resolver),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.koda.koda.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationChannelDescription: 'Controles de reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
