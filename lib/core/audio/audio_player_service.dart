import '../domain/entities/song.dart';

/// Estados del reproductor expuestos a la UI. Son nuestros, no de
/// just_audio, para que la UI no dependa del motor de audio.
enum PlaybackStatus { idle, loading, buffering, ready, completed, error }

enum PlayerRepeatMode { off, one, all }

/// Instantánea del reproductor que consume la UI (mini-player, pantalla
/// de reproducción, notificación).
class PlayerSnapshot {
  const PlayerSnapshot({
    this.status = PlaybackStatus.idle,
    this.isPlaying = false,
    this.currentSong,
    this.queue = const [],
    this.currentIndex,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.repeatMode = PlayerRepeatMode.off,
    this.shuffleEnabled = false,
    this.isPlayingOffline = false,
    this.errorMessage,
    this.stopAfterCurrent = false,
  });

  final PlaybackStatus status;
  final bool isPlaying;
  final Song? currentSong;
  final List<Song> queue;
  final int? currentIndex;
  final Duration position;
  final Duration bufferedPosition;
  final PlayerRepeatMode repeatMode;
  final bool shuffleEnabled;

  /// true si la pista actual se está leyendo desde archivo local.
  /// Útil para mostrar el icono de "offline" en el reproductor.
  final bool isPlayingOffline;

  final String? errorMessage;

  /// true si el reproductor se parará al terminar la canción actual.
  final bool stopAfterCurrent;

  bool get hasNext => currentIndex != null && currentIndex! < queue.length - 1;
  bool get hasPrevious => currentIndex != null && currentIndex! > 0;

  /// La que sonará con "siguiente": la próxima de la cola o, con repetir
  /// todo, la primera. La cola ya está en orden aleatorio si toca.
  Song? get nextSong {
    final i = currentIndex;
    if (i == null || queue.isEmpty) return null;
    if (i < queue.length - 1) return queue[i + 1];
    return repeatMode == PlayerRepeatMode.all ? queue.first : null;
  }

  /// La anterior de la cola, sin dar la vuelta.
  Song? get previousSong => hasPrevious ? queue[currentIndex! - 1] : null;
}

/// Fachada única del audio en la app. La implementación (Paso 2) envuelve
/// un `BaseAudioHandler` de audio_service + `AudioPlayer` de just_audio y
/// usa un [PlaybackSourceResolver] para elegir local vs streaming por cada
/// canción, de forma transparente para quien llama.
abstract interface class AudioPlayerService {
  /// Estado completo; emite en cada cambio relevante.
  Stream<PlayerSnapshot> get snapshots;

  /// Posición con alta frecuencia (barra de progreso), separada de
  /// [snapshots] para no reconstruir toda la UI varias veces por segundo.
  Stream<Duration> get positionStream;

  PlayerSnapshot get current;

  // --- Carga de cola -----------------------------------------------------

  /// Reproduce una sola canción reemplazando la cola.
  Future<void> playSong(Song song);

  /// Reemplaza la cola (p. ej. al tocar una canción de una playlist) y
  /// empieza en [startIndex]. Cada canción se resuelve a local o streaming
  /// justo antes de sonar, no todas de golpe.
  Future<void> playQueue(List<Song> songs, {int startIndex = 0});

  Future<void> addToQueue(Song song);
  Future<void> playNext(Song song);
  Future<void> removeFromQueue(int index);
  Future<void> moveInQueue(int oldIndex, int newIndex);

  // --- Transporte --------------------------------------------------------

  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);

  // --- Modos -------------------------------------------------------------

  /// Se llama `setRepeat` (y no `setRepeatMode`) para no chocar con el
  /// método homónimo de `AudioHandler`, que usa otro tipo.
  Future<void> setRepeat(PlayerRepeatMode mode);
  Future<void> setShuffle(bool enabled);

  /// Llamado por el gestor de descargas (Paso 3) cuando una canción de la
  /// cola termina de descargarse o se borra, para que la siguiente vez que
  /// suene use la fuente correcta sin cortar la reproducción actual.
  Future<void> onSongStorageChanged(Song updated);

  // --- Ganchos para otras funcionalidades -------------------------------

  /// Emite cada canción cuando empieza a sonar (p. ej. para el historial).
  Stream<Song> get songStarted;

  /// Si está definido, se llama al terminar la cola (sin "repetir todo") con
  /// la cola actual; las canciones que devuelva se añaden al final y siguen
  /// sonando (p. ej. radio automática). Una lista vacía para la cola.
  QueueEndedCallback? get onQueueEnded;
  set onQueueEnded(QueueEndedCallback? callback);

  /// Para al terminar la canción actual en vez de pasar a la siguiente. Se
  /// desactiva solo después de usarse. Ver [PlayerSnapshot.stopAfterCurrent].
  Future<void> setStopAfterCurrent(bool enabled);

  Future<void> dispose();
}

typedef QueueEndedCallback = Future<List<Song>> Function(List<Song> queue);
