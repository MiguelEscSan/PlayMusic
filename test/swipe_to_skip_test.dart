import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/audio_providers.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/player/presentation/mini_player.dart';
import 'package:sponify/features/player/presentation/swipe_to_skip.dart';

const _key = Key('swipe-content');

class _Calls {
  int next = 0;
  int previous = 0;
  int taps = 0;
}

Widget _harness(
  _Calls calls, {
  bool canSkipNext = true,
  bool canSkipPrevious = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 80,
          child: SwipeToSkip(
            canSkipNext: canSkipNext,
            canSkipPrevious: canSkipPrevious,
            onNext: () => calls.next++,
            onPrevious: () => calls.previous++,
            child: InkWell(
              key: _key,
              onTap: () => calls.taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

Song _song(int i) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
);

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
    testWidgets('fling left skips to the next song', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));

      await tester.fling(find.byKey(_key), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.next, 1);
      expect(calls.previous, 0);
    });

    testWidgets('fling right skips to the previous song', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));

      await tester.fling(find.byKey(_key), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.previous, 1);
      expect(calls.next, 0);
    });

    testWidgets('slow drag past the threshold also commits', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_key)),
      );
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.next, 1);
    });

    testWidgets('small slow drag snaps back without skipping', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));
      final origin = tester.getTopLeft(find.byKey(_key));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_key)),
      );
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.next, 0);
      expect(calls.previous, 0);
      expect(tester.getTopLeft(find.byKey(_key)), origin);
    });

    testWidgets('does nothing when there is no song in that direction', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _harness(calls, canSkipNext: false, canSkipPrevious: false),
      );
      final origin = tester.getTopLeft(find.byKey(_key));

      await tester.fling(find.byKey(_key), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      await tester.fling(find.byKey(_key), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(calls.next, 0);
      expect(calls.previous, 0);
      expect(tester.getTopLeft(find.byKey(_key)), origin);
    });

    testWidgets('taps and vertical drags still reach the child', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_harness(calls));

      await tester.tap(find.byKey(_key));
      await tester.fling(find.byKey(_key), const Offset(0, -200), 1500);
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

    final queue = [_song(0), _song(1), _song(2)];

    testWidgets('swipes change songs in both directions', (tester) async {
      final audio = await pumpMiniPlayer(
        tester,
        PlayerSnapshot(currentSong: queue[1], queue: queue, currentIndex: 1),
      );

      await tester.fling(find.text('Canción 1'), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      await tester.fling(find.text('Canción 1'), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(audio.next, 1);
      // Siempre la pista anterior, nunca el reinicio de skipToPrevious.
      expect(audio.skippedTo, [0]);
      expect(audio.previous, 0);
    });

    testWidgets('no swipe at the edges of the queue', (tester) async {
      final audio = await pumpMiniPlayer(
        tester,
        PlayerSnapshot(
          currentSong: queue[0],
          queue: [queue[0]],
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
