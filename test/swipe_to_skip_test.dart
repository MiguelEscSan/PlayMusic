import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/audio_providers.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/player/presentation/mini_player.dart';
import 'package:sponify/features/player/presentation/swipe_to_skip.dart';

Song _song(int i) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista $i',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
);

final _queue = [_song(0), _song(1), _song(2)];

class _Calls {
  int next = 0;
  int previous = 0;
  int taps = 0;
}

Widget _harness(_Calls calls, {Song? current, Song? next, Song? previous}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 80,
          child: SwipeToSkip(
            current: current ?? _queue[1],
            next: next,
            previous: previous,
            onNext: () => calls.next++,
            onPrevious: () => calls.previous++,
            itemBuilder: (context, song) => InkWell(
              onTap: () => calls.taps++,
              child: Center(child: Text(song.title)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Arrastra despacio (sin velocidad de fling) [steps] tramos de [step].
Future<TestGesture> _slowDrag(
  WidgetTester tester,
  Offset step,
  int steps,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(SwipeToSkip)),
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 100));
  }
  return gesture;
}

/// Deja que venza la espera de confirmación del reproductor.
Future<void> _expirePending(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

class _FakeAudio implements AudioPlayerService {
  int next = 0;
  int previous = 0;
  final skippedTo = <int>[];

  @override
  Future<void> skipToNext() async => next++;

  @override
  Future<void> skipToPrevious() async => previous++;

  @override
  Future<void> skipToIndex(int index) async => skippedTo.add(index);

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SwipeToSkip', () {
    testWidgets('dragging left previews the next song from the edge', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _harness(calls, next: _queue[2], previous: _queue[0]),
      );
      expect(find.text('Canción 2'), findsNothing);

      final gesture = await _slowDrag(tester, const Offset(-20, 0), 4);

      expect(find.text('Canción 2'), findsOneWidget);
      expect(find.text('Canción 0'), findsNothing);
      // La vecina entra desde la derecha, pegada a la actual.
      expect(
        tester.getCenter(find.text('Canción 2')).dx,
        greaterThan(tester.getCenter(find.text('Canción 1')).dx),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dragging right previews the previous song', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _harness(calls, next: _queue[2], previous: _queue[0]),
      );

      final gesture = await _slowDrag(tester, const Offset(20, 0), 4);

      expect(find.text('Canción 0'), findsOneWidget);
      expect(find.text('Canción 2'), findsNothing);
      expect(
        tester.getCenter(find.text('Canción 0')).dx,
        lessThan(tester.getCenter(find.text('Canción 1')).dx),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('fling left settles on the next song and skips', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls, next: _queue[2]));

      await tester.fling(find.byType(SwipeToSkip), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.next, 1);
      expect(calls.previous, 0);
      // Mientras el reproductor carga, se queda la nueva en el centro.
      expect(find.text('Canción 2'), findsOneWidget);
      expect(find.text('Canción 1'), findsNothing);

      // El reproductor confirma: sigue la nueva, ya como actual.
      await tester.pumpWidget(_harness(calls, current: _queue[2]));
      await tester.pumpAndSettle();
      expect(find.text('Canción 2'), findsOneWidget);
    });

    testWidgets('fling right settles on the previous song and skips', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls, previous: _queue[0]));

      await tester.fling(find.byType(SwipeToSkip), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.previous, 1);
      expect(calls.next, 0);
      expect(find.text('Canción 0'), findsOneWidget);
      await _expirePending(tester);
    });

    testWidgets('slow drag past the threshold also commits', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls, next: _queue[2]));

      final gesture = await _slowDrag(tester, const Offset(-10, 0), 12);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.next, 1);
      await _expirePending(tester);
    });

    testWidgets('small slow drag slides the preview back out', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _harness(calls, next: _queue[2], previous: _queue[0]),
      );
      final origin = tester.getCenter(find.text('Canción 1'));

      final gesture = await _slowDrag(tester, const Offset(-10, 0), 5);
      expect(find.text('Canción 2'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.next, 0);
      expect(calls.previous, 0);
      expect(find.text('Canción 2'), findsNothing);
      expect(tester.getCenter(find.text('Canción 1')), origin);
    });

    testWidgets('without a neighbour it only rubber-bands back', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));
      final origin = tester.getCenter(find.text('Canción 1'));

      final gesture = await _slowDrag(tester, const Offset(-20, 0), 5);
      // Cede, pero bastante menos que el dedo (100 px).
      final moved = origin.dx - tester.getCenter(find.text('Canción 1')).dx;
      expect(moved, greaterThan(0));
      expect(moved, lessThan(50));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.fling(find.byType(SwipeToSkip), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(SwipeToSkip), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.next, 0);
      expect(calls.previous, 0);
      expect(tester.getCenter(find.text('Canción 1')), origin);
    });

    testWidgets('falls back to the real current song if no change arrives', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls, next: _queue[2]));

      await tester.fling(find.byType(SwipeToSkip), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Canción 2'), findsOneWidget);

      await _expirePending(tester);
      expect(find.text('Canción 1'), findsOneWidget);
      expect(find.text('Canción 2'), findsNothing);
    });

    testWidgets('taps and vertical drags still reach the child', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _harness(calls, next: _queue[2], previous: _queue[0]),
      );

      await tester.tap(find.text('Canción 1'));
      await tester.fling(find.byType(SwipeToSkip), const Offset(0, -200), 1500);
      await tester.pumpAndSettle();

      expect(calls.taps, 1);
      expect(calls.next, 0);
      expect(calls.previous, 0);
    });
  });

  group('MiniPlayer swipe', () {
    Future<_FakeAudio> pumpMiniPlayer(
      WidgetTester tester,
      PlayerSnapshot snapshot,
    ) async {
      final audio = _FakeAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            playerSnapshotProvider.overrideWith(
              (ref) => Stream.value(snapshot),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: MiniPlayer()),
          ),
        ),
      );
      await tester.pump();
      return audio;
    }

    testWidgets('previews and changes songs in both directions', (
      tester,
    ) async {
      final audio = await pumpMiniPlayer(
        tester,
        PlayerSnapshot(currentSong: _queue[1], queue: _queue, currentIndex: 1),
      );

      final gesture = await _slowDrag(tester, const Offset(-20, 0), 3);
      expect(find.text('Canción 2'), findsOneWidget);
      expect(find.text('Artista 2'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.fling(find.text('Canción 1'), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      await _expirePending(tester);
      await tester.fling(find.text('Canción 1'), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();
      await _expirePending(tester);

      expect(audio.next, 1);
      // Siempre la pista anterior, nunca el reinicio de skipToPrevious.
      expect(audio.skippedTo, [0]);
      expect(audio.previous, 0);
    });

    testWidgets('repeat all previews the first song after the last one', (
      tester,
    ) async {
      await pumpMiniPlayer(
        tester,
        PlayerSnapshot(
          currentSong: _queue[2],
          queue: _queue,
          currentIndex: 2,
          repeatMode: PlayerRepeatMode.all,
        ),
      );

      final gesture = await _slowDrag(tester, const Offset(-20, 0), 3);
      expect(find.text('Canción 0'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('no swipe at the edges of the queue', (tester) async {
      final audio = await pumpMiniPlayer(
        tester,
        PlayerSnapshot(
          currentSong: _queue[0],
          queue: [_queue[0]],
          currentIndex: 0,
        ),
      );

      await tester.fling(find.text('Canción 0'), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      await tester.fling(find.text('Canción 0'), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(audio.next, 0);
      expect(audio.skippedTo, isEmpty);
      expect(audio.previous, 0);
    });
  });
}
