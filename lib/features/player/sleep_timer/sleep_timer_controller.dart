import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/audio/audio_providers.dart';

/// Estado del temporizador de apagado.
sealed class SleepTimerState {
  const SleepTimerState();
}

/// Sin temporizador.
class SleepTimerOff extends SleepTimerState {
  const SleepTimerOff();
}

/// Cuenta atrás: al llegar a [endsAt] se pausa la reproducción.
class SleepTimerCountdown extends SleepTimerState {
  const SleepTimerCountdown({required this.endsAt, required this.remaining});

  final DateTime endsAt;

  /// Tiempo restante, actualizado cada segundo.
  final Duration remaining;

  /// Minutos restantes redondeados hacia arriba (para la etiqueta del botón).
  int get remainingMinutes => (remaining.inSeconds + 59) ~/ 60;
}

/// Parar al terminar la canción actual (usa `stopAfterCurrent`).
class SleepTimerEndOfSong extends SleepTimerState {
  const SleepTimerEndOfSong();
}

/// Reloj y temporizadores inyectables para poder probar sin esperas reales.
class SleepTimerClock {
  const SleepTimerClock();

  DateTime now() => DateTime.now();

  Timer periodic(Duration period, void Function(Timer) callback) =>
      Timer.periodic(period, callback);
}

final sleepTimerClockProvider = Provider<SleepTimerClock>(
  (ref) => const SleepTimerClock(),
);

/// Temporizador de apagado. No es autoDispose: debe seguir contando aunque
/// se cierre la pantalla de reproducción.
final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
    );

class SleepTimerController extends Notifier<SleepTimerState> {
  static const _tickPeriod = Duration(seconds: 1);

  Timer? _ticker;
  StreamSubscription<PlayerSnapshot>? _snapshotSub;

  /// true cuando el reproductor ya confirmó `stopAfterCurrent`; así no nos
  /// apagamos por una instantánea antigua emitida antes de activarlo.
  bool _sawStopFlag = false;

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);
  SleepTimerClock get _clock => ref.read(sleepTimerClockProvider);

  @override
  SleepTimerState build() {
    _snapshotSub = ref
        .watch(audioPlayerServiceProvider)
        .snapshots
        .listen(_onSnapshot);
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      _snapshotSub?.cancel();
    });
    return const SleepTimerOff();
  }

  /// Pausa la reproducción dentro de [duration]. Sustituye cualquier
  /// temporizador anterior.
  void start(Duration duration) {
    _clear();
    final endsAt = _clock.now().add(duration);
    state = SleepTimerCountdown(endsAt: endsAt, remaining: duration);
    _ticker = _clock.periodic(_tickPeriod, (_) => _onTick(endsAt));
  }

  /// Para al terminar la canción actual. Sustituye cualquier temporizador
  /// anterior.
  void startEndOfSong() {
    _clear();
    _sawStopFlag = false;
    state = const SleepTimerEndOfSong();
    _audio.setStopAfterCurrent(true);
  }

  /// Desactiva el temporizador sin pausar nada.
  void cancel() {
    _clear();
    state = const SleepTimerOff();
  }

  /// Detiene el temporizador activo (cuenta atrás o fin de canción).
  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    if (state is SleepTimerEndOfSong) {
      _audio.setStopAfterCurrent(false);
    }
  }

  void _onTick(DateTime endsAt) {
    final remaining = endsAt.difference(_clock.now());
    if (remaining > Duration.zero) {
      state = SleepTimerCountdown(endsAt: endsAt, remaining: remaining);
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    state = const SleepTimerOff();
    _audio.pause();
  }

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (state is! SleepTimerEndOfSong) return;
    if (snapshot.stopAfterCurrent) {
      _sawStopFlag = true;
    } else if (_sawStopFlag) {
      // El reproductor ya se paró al final de la canción y reseteó la bandera.
      state = const SleepTimerOff();
    }
  }
}
