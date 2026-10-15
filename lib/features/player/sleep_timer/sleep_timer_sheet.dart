import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sleep_timer_controller.dart';

const _minuteOptions = [5, 15, 30, 45, 60];

/// Hoja inferior para elegir el temporizador de apagado.
Future<void> showSleepTimerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SleepTimerSheet(),
    );

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider);
    final controller = ref.read(sleepTimerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    void choose(VoidCallback action) {
      action();
      Navigator.pop(context);
    }

    final subtitle = switch (state) {
      SleepTimerCountdown(:final remainingMinutes) =>
        'Se pausará en $remainingMinutes min',
      SleepTimerEndOfSong() => 'Se parará al terminar la canción',
      SleepTimerOff() => null,
    };

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                'Temporizador',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: subtitle == null ? null : Text(subtitle),
            ),
            for (final minutes in _minuteOptions)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes minutos'),
                onTap: () =>
                    choose(() => controller.start(Duration(minutes: minutes))),
              ),
            ListTile(
              leading: Icon(
                Icons.music_off_outlined,
                color: state is SleepTimerEndOfSong ? scheme.primary : null,
              ),
              title: const Text('Al terminar la canción'),
              onTap: () => choose(controller.startEndOfSong),
            ),
            if (state is! SleepTimerOff)
              ListTile(
                leading: Icon(Icons.timer_off_outlined, color: scheme.error),
                title: const Text('Desactivar'),
                onTap: () => choose(controller.cancel),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de la barra superior del reproductor. Se colorea cuando hay un
/// temporizador activo y muestra los minutos restantes en una insignia.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;
    final active = state is! SleepTimerOff;

    Widget icon = Icon(
      active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
      color: active ? scheme.primary : null,
    );
    if (state case SleepTimerCountdown(:final remainingMinutes)) {
      icon = Badge(
        label: Text('$remainingMinutes'),
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        child: icon,
      );
    }

    return IconButton(
      tooltip: 'Temporizador',
      icon: icon,
      onPressed: () => showSleepTimerSheet(context),
    );
  }
}
