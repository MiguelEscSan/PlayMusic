import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/player/sleep_timer/sleep_timer_controller.dart';
import 'package:sponify/features/player/sleep_timer/sleep_timer_sheet.dart';

/// Servicio de audio falso: solo registra las llamadas que nos interesan.
class _FakeAudio implements AudioPlayerService {
  final calls = <String>[];
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();

  void emit(PlayerSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> setStopAfterCurrent(bool enabled) async =>
      calls.add('stopAfterCurrent:$enabled');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Temporizador manual que dispara cuando el reloj falso avanza.
class _FakeTimer implements Timer {
  _FakeTimer(this.clock, this.period, this.callback)
    : _next = clock._now.add(period);

  final _FakeClock clock;
  final Duration period;
  final void Function(Timer) callback;
  DateTime _next;
  bool _active = true;
  int _tick = 0;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

/// Reloj controlado por el test: `advance` mueve la hora y dispara los
/// temporizadores periódicos vencidos, sin esperas reales.
class _FakeClock implements SleepTimerClock {
  DateTime _now = DateTime(2026, 1, 1, 22);
  final _timers = <_FakeTimer>[];

  @override
  DateTime now() => _now;

  @override
  Timer periodic(Duration period, void Function(Timer) callback) {
    final timer = _FakeTimer(this, period, callback);
    _timers.add(timer);
    return timer;
  }

  int get activeTimers => _timers.where((t) => t.isActive).length;

  void advance(Duration duration) {
    final target = _now.add(duration);
    while (true) {
      final due =
          _timers.where((t) => t.isActive && !t._next.isAfter(target)).toList()
            ..sort((a, b) => a._next.compareTo(b._next));
      if (due.isEmpty) break;
      final timer = due.first;
      _now = timer._next;
      timer._next = timer._next.add(timer.period);
      timer._tick++;
      timer.callback(timer);
    }
    _now = target;
  }
}

void main() {
  late _FakeAudio audio;
  late _FakeClock clock;
  late ProviderContainer container;

  setUp(() {
    audio = _FakeAudio();
    clock = _FakeClock();
    container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audio),
        sleepTimerClockProvider.overrideWithValue(clock),
      ],
    );
    container.listen(sleepTimerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  SleepTimerState state() => container.read(sleepTimerProvider);
  SleepTimerController controller() =>
      container.read(sleepTimerProvider.notifier);

  test('empieza apagado', () {
    expect(state(), isA<SleepTimerOff>());
  });

  test('la cuenta atrás pausa al llegar a cero y se apaga', () {
    controller().start(const Duration(minutes: 5));

    final running = state() as SleepTimerCountdown;
    expect(running.remaining, const Duration(minutes: 5));

    clock.advance(const Duration(minutes: 2));
    expect((state() as SleepTimerCountdown).remaining.inMinutes, 3);
    expect(audio.calls, isEmpty);

    clock.advance(const Duration(minutes: 3));
    expect(audio.calls, ['pause']);
    expect(state(), isA<SleepTimerOff>());
    expect(clock.activeTimers, 0);
  });

  test('cancelar evita la pausa', () {
    controller().start(const Duration(minutes: 5));
    clock.advance(const Duration(minutes: 1));
    controller().cancel();

    expect(state(), isA<SleepTimerOff>());
    clock.advance(const Duration(minutes: 10));
    expect(audio.calls, isEmpty);
  });

  test(
    'al terminar la canción activa y cancelar desactiva stopAfterCurrent',
    () {
      controller().startEndOfSong();
      expect(state(), isA<SleepTimerEndOfSong>());
      expect(audio.calls, ['stopAfterCurrent:true']);

      controller().cancel();
      expect(state(), isA<SleepTimerOff>());
      expect(audio.calls, ['stopAfterCurrent:true', 'stopAfterCurrent:false']);
    },
  );

  test('cancelar una cuenta atrás no toca stopAfterCurrent', () {
    controller().start(const Duration(minutes: 15));
    controller().cancel();
    expect(audio.calls, isEmpty);
  });

  test('cambiar de opción reemplaza el temporizador anterior', () {
    controller().start(const Duration(minutes: 5));
    controller().start(const Duration(minutes: 30));
    expect(clock.activeTimers, 1);

    clock.advance(const Duration(minutes: 10));
    expect(audio.calls, isEmpty);
    expect((state() as SleepTimerCountdown).remaining.inMinutes, 20);

    controller().startEndOfSong();
    expect(clock.activeTimers, 0);
    expect(state(), isA<SleepTimerEndOfSong>());

    controller().start(const Duration(minutes: 15));
    expect(audio.calls, ['stopAfterCurrent:true', 'stopAfterCurrent:false']);
    expect(state(), isA<SleepTimerCountdown>());

    clock.advance(const Duration(minutes: 60));
    expect(audio.calls.last, 'pause');
  });

  test(
    'al terminar la canción se apaga cuando el reproductor se para',
    () async {
      controller().startEndOfSong();

      // Aún no ha llegado la confirmación del reproductor: sigue activo.
      audio.emit(const PlayerSnapshot());
      await pumpEventQueue();
      expect(state(), isA<SleepTimerEndOfSong>());

      audio.emit(const PlayerSnapshot(stopAfterCurrent: true));
      await pumpEventQueue();
      expect(state(), isA<SleepTimerEndOfSong>());

      // El reproductor se paró al final y reseteó la bandera.
      audio.emit(const PlayerSnapshot());
      await pumpEventQueue();
      expect(state(), isA<SleepTimerOff>());
    },
  );

  testWidgets('el botón abre la hoja y muestra los minutos restantes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          sleepTimerClockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [SleepTimerButton()])),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Temporizador'));
    await tester.pumpAndSettle();
    expect(find.text('Temporizador'), findsOneWidget);
    expect(find.text('Desactivar'), findsNothing);

    await tester.tap(find.text('15 minutos'));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.byTooltip('Temporizador'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Desactivar'));
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsNothing);
  });
}
