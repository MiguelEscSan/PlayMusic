import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'audio_player_service.dart';
import 'http_range_audio_source.dart';
import 'playback_source.dart';

/// Reproductor de la app: une just_audio (motor), audio_service (controles
/// en notificación / pantalla de bloqueo / auriculares) y el
/// [PlaybackSourceResolver] (local vs streaming).
///
/// Decisión clave: la cola la gestionamos nosotros y cargamos en just_audio
/// UNA canción cada vez. Así cada pista se resuelve justo antes de sonar
/// (las URLs de YouTube caducan y un archivo puede descargarse mientras
/// tanto). La siguiente se pre-resuelve en segundo plano para que el salto
/// sea rápido.
class SponifyAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayerService {
  SponifyAudioHandler({required this._resolver, AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subs
      ..add(_player.playbackEventStream.listen((_) => _broadcast()))
      ..add(_player.playingStream.listen((_) => _broadcast()))
      ..add(
        _player.processingStateStream.listen((state) {
          if (state == ProcessingState.completed) _onTrackCompleted();
        }),
      )
      ..add(_player.errorStream.listen(_onPlaybackError));
    _broadcast();
  }

  final PlaybackSourceResolver _resolver;
  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subs = [];
  final _snapshotController = StreamController<PlayerSnapshot>.broadcast();
  final _random = Random();

  /// Orden de reproducción actual.
  List<Song> _queue = [];

  /// Orden original mientras el aleatorio está activo (para restaurarlo).
  List<Song>? _unshuffled;

  int? _index;
  PlayerRepeatMode _repeat = PlayerRepeatMode.off;
  bool _resolving = false;
  bool _playingOffline = false;
  bool _retriedCurrent = false;
  String? _error;

  /// Se incrementa en cada carga; si el usuario salta varias veces seguidas,
  /// las cargas antiguas detectan que ya no son la vigente y se descartan.
  int _loadGeneration = 0;

  PlayerSnapshot _snapshot = const PlayerSnapshot();

  Song? get _currentSong =>
      (_index != null && _index! < _queue.length) ? _queue[_index!] : null;
  bool get _hasNext => _index != null && _index! < _queue.length - 1;
  bool get _hasPrevious => _index != null && _index! > 0;

  // ===========================================================================
  // AudioPlayerService: estado
  // ===========================================================================

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _snapshotController.stream;
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  PlayerSnapshot get current => _snapshot;

  // ===========================================================================
  // AudioPlayerService: cola
  // ===========================================================================

  @override
  Future<void> playSong(Song song) => playQueue([song]);

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return stop();
    RangeError.checkValidIndex(startIndex, songs, 'startIndex');
    if (_shuffleEnabled) {
      _unshuffled = [...songs];
      final first = songs[startIndex];
      _queue = [
        first,
        ..._shuffled([...songs]..removeAt(startIndex)),
      ];
      startIndex = 0;
    } else {
      _unshuffled = null;
      _queue = [...songs];
    }
    _publishQueue();
    await _loadAt(startIndex);
  }

  @override
  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    _unshuffled?.add(song);
    _publishQueue();
    if (_index == null) await _loadAt(_queue.length - 1);
  }

  @override
  Future<void> playNext(Song song) async {
    final insertAt = _index == null ? 0 : _index! + 1;
    _queue.insert(insertAt, song);
    if (_unshuffled case final original?) {
      final cur = _currentSong;
      final pos = cur == null
          ? -1
          : original.indexWhere((s) => identical(s, cur));
      original.insert(pos + 1, song);
    }
    _publishQueue();
    if (_index == null) await _loadAt(insertAt);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    RangeError.checkValidIndex(index, _queue, 'index');
    final removed = _queue.removeAt(index);
    _unshuffled?.removeWhere((s) => identical(s, removed));
    _publishQueue();

    final cur = _index;
    if (cur == null) return _broadcast();
    if (index < cur) {
      _index = cur - 1;
      _broadcast();
    } else if (index > cur) {
      _broadcast();
    } else {
      // Se quitó la que sonaba: pasamos a la que ocupa su lugar.
      if (_queue.isEmpty) return stop();
      final wasPlaying = _player.playing;
      await _loadAt(min(cur, _queue.length - 1), autoplay: wasPlaying);
    }
  }

  /// [newIndex] es la posición final de la canción (ya ajustada, no la que
  /// entrega `ReorderableListView` sin corregir).
  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final cur = _currentSong;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (cur != null) _index = _queue.indexWhere((s) => identical(s, cur));
    _publishQueue();
    _broadcast();
  }

  // ===========================================================================
  // Transporte (comparten nombre con AudioHandler: los botones de la
  // notificación y los de la UI llaman exactamente al mismo código)
  // ===========================================================================

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    final needsReload =
        _index == null ||
        _error != null ||
        _player.processingState == ProcessingState.idle;
    if (needsReload) return _loadAt(_index ?? 0);
    // play() de just_audio no completa hasta que se pausa: no esperarlo.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> togglePlayPause() => _player.playing ? pause() : play();

  @override
  Future<void> stop() async {
    _loadGeneration++;
    _resolving = false;
    await _player.stop();
    _broadcast();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_hasNext) return _loadAt(_index! + 1);
    if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) return _loadAt(0);
  }

  /// Como en cualquier reproductor: si van más de 3 s, vuelve al inicio de
  /// la canción; si no, a la anterior.
  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3) || !_hasPrevious) {
      return seek(Duration.zero);
    }
    return _loadAt(_index! - 1);
  }

  @override
  Future<void> skipToIndex(int index) async {
    RangeError.checkValidIndex(index, _queue, 'index');
    return _loadAt(index);
  }

  @override
  Future<void> skipToQueueItem(int index) => skipToIndex(index);

  @override
  Future<void> removeQueueItemAt(int index) => removeFromQueue(index);

  // ===========================================================================
  // Modos
  // ===========================================================================

  @override
  Future<void> setRepeat(PlayerRepeatMode mode) async {
    _repeat = mode;
    // Repetir una: lo hace just_audio sin cortes. Repetir todo: lo
    // gestionamos en _onTrackCompleted porque la cola es nuestra.
    await _player.setLoopMode(
      mode == PlayerRepeatMode.one ? LoopMode.one : LoopMode.off,
    );
    _broadcast();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      setRepeat(switch (repeatMode) {
        AudioServiceRepeatMode.none => PlayerRepeatMode.off,
        AudioServiceRepeatMode.one => PlayerRepeatMode.one,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => PlayerRepeatMode.all,
      });

  @override
  Future<void> setShuffle(bool enabled) async {
    if (enabled == _shuffleEnabled) return;
    final cur = _currentSong;
    if (enabled) {
      _unshuffled = [..._queue];
      final rest = [..._queue]..removeWhere((s) => identical(s, cur));
      _queue = [?cur, ..._shuffled(rest)];
      _index = cur == null ? null : 0;
    } else if (_unshuffled case final original?) {
      _queue = original;
      _unshuffled = null;
      _index = cur == null ? null : _queue.indexWhere((s) => identical(s, cur));
    }
    _shuffleEnabled = enabled;
    _publishQueue();
    _broadcast();
  }

  bool _shuffleEnabled = false;

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  // ===========================================================================
  // Integración con descargas (Paso 3)
  // ===========================================================================

  @override
  Future<void> onSongStorageChanged(Song updated) async {
    Song swap(Song s) => s == updated ? updated : s;
    _queue = _queue.map(swap).toList();
    _unshuffled = _unshuffled?.map(swap).toList();
    // Si es la que suena no la recargamos: seguirá en streaming hasta el
    // final y la próxima vez se leerá del archivo.
    _publishQueue();
    _broadcast();
  }

  // ===========================================================================
  // Ciclo de vida
  // ===========================================================================

  /// El usuario cerró la app desde recientes: paramos y liberamos el servicio.
  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _snapshotController.close();
  }

  // ===========================================================================
  // Núcleo: cargar una canción decidiendo local vs streaming
  // ===========================================================================

  Future<void> _loadAt(
    int index, {
    bool autoplay = true,
    bool forceRefresh = false,
  }) async {
    final generation = ++_loadGeneration;
    final song = _queue[index];
    _index = index;
    _error = null;
    _resolving = true;
    if (!forceRefresh) _retriedCurrent = false;
    mediaItem.add(_toMediaItem(song));
    _broadcast();

    final PlaybackSource source;
    try {
      source = await _resolver.resolve(song, forceRefresh: forceRefresh);
    } on SongUnavailableException catch (e) {
      if (generation != _loadGeneration) return;
      _fail(e.reason ?? 'Canción no disponible');
      // Sin conexión, saltamos a la siguiente que sí se pueda reproducir
      // (normalmente una descargada).
      if (autoplay && _hasNext) await _loadAt(index + 1);
      return;
    }
    if (generation != _loadGeneration) return; // el usuario ya cambió de pista

    _playingOffline = source is LocalFileSource;
    mediaItem.add(_toMediaItem(song, offline: _playingOffline));

    try {
      await _player.setAudioSource(_toAudioSource(source, song));
    } on PlayerInterruptedException {
      return; // otra carga la sustituyó
    } on PlayerException catch (e) {
      if (generation != _loadGeneration) return;
      await _handleLoadFailure(e, source, index, autoplay);
      return;
    }
    if (generation != _loadGeneration) return;

    _resolving = false;
    _broadcast();
    if (autoplay) unawaited(_player.play());
    _prefetchNext();
  }

  Future<void> _handleLoadFailure(
    PlayerException e,
    PlaybackSource source,
    int index,
    bool autoplay,
  ) async {
    // Una URL remota rechazada suele estar caducada: un reintento con URL
    // nueva lo arregla casi siempre.
    if (source is RemoteStreamSource && !_retriedCurrent) {
      _retriedCurrent = true;
      return _loadAt(index, autoplay: autoplay, forceRefresh: true);
    }
    _fail(e.message ?? 'Error de reproducción (${e.code})');
    if (autoplay && _hasNext) await _loadAt(index + 1);
  }

  /// Error en mitad de la reproducción (p. ej. se corta la red o la URL
  /// caduca durante una canción larga): reintenta desde la misma posición.
  Future<void> _onPlaybackError(PlayerException e) async {
    final index = _index;
    if (index == null || _resolving || _playingOffline || _retriedCurrent) {
      _fail(e.message ?? 'Error de reproducción');
      return;
    }
    final position = _player.position;
    _retriedCurrent = true;
    await _loadAt(index, autoplay: true, forceRefresh: true);
    if (_index == index) await _player.seek(position);
  }

  Future<void> _onTrackCompleted() async {
    if (_hasNext) return _loadAt(_index! + 1);
    if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) return _loadAt(0);
    // Fin de la cola: dejamos la última canción preparada al principio.
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  /// Calienta la caché de URLs del resolver para la siguiente canción.
  void _prefetchNext() {
    final next = _hasNext
        ? _queue[_index! + 1]
        : (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty
              ? _queue.first
              : null);
    if (next == null || next.isDownloaded) return;
    unawaited(_resolver.resolve(next).then((_) {}, onError: (_) {}));
  }

  void _fail(String message) {
    _resolving = false;
    _error = message;
    _broadcast();
  }

  // ===========================================================================
  // Traducciones a just_audio / audio_service
  // ===========================================================================

  AudioSource _toAudioSource(PlaybackSource source, Song song) =>
      switch (source) {
        LocalFileSource(:final filePath) => AudioSource.file(
          filePath,
          tag: song.id,
        ),
        RemoteStreamSource(:final uri, :final headers) => HttpRangeAudioSource(
          uri,
          headers: headers,
          tag: song.id,
        ),
      };

  MediaItem _toMediaItem(Song song, {bool offline = false}) => MediaItem(
    id: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.durationMs > 0 ? song.duration : null,
    artUri: song.artworkUrl == null ? null : Uri.tryParse(song.artworkUrl!),
    extras: {'offline': offline},
  );

  void _publishQueue() {
    queue.add(_queue.map(_toMediaItem).toList());
  }

  List<Song> _shuffled(List<Song> songs) => songs..shuffle(_random);

  void _broadcast() {
    final playing = _player.playing;
    final status = _error != null
        ? PlaybackStatus.error
        : _resolving
        ? PlaybackStatus.loading
        : switch (_player.processingState) {
            ProcessingState.idle => PlaybackStatus.idle,
            ProcessingState.loading => PlaybackStatus.loading,
            ProcessingState.buffering => PlaybackStatus.buffering,
            ProcessingState.ready => PlaybackStatus.ready,
            ProcessingState.completed => PlaybackStatus.completed,
          };

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (status) {
          PlaybackStatus.idle => AudioProcessingState.idle,
          PlaybackStatus.loading => AudioProcessingState.loading,
          PlaybackStatus.buffering => AudioProcessingState.buffering,
          PlaybackStatus.ready => AudioProcessingState.ready,
          PlaybackStatus.completed => AudioProcessingState.completed,
          PlaybackStatus.error => AudioProcessingState.error,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _index,
        repeatMode: switch (_repeat) {
          PlayerRepeatMode.off => AudioServiceRepeatMode.none,
          PlayerRepeatMode.one => AudioServiceRepeatMode.one,
          PlayerRepeatMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorMessage: _error,
      ),
    );

    _snapshot = PlayerSnapshot(
      status: status,
      isPlaying: playing,
      currentSong: _currentSong,
      queue: List.unmodifiable(_queue),
      currentIndex: _index,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      repeatMode: _repeat,
      shuffleEnabled: _shuffleEnabled,
      isPlayingOffline: _playingOffline,
      errorMessage: _error,
    );
    if (!_snapshotController.isClosed) _snapshotController.add(_snapshot);
  }
}
