import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/player/presentation/player_providers.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/player/presentation/now_playing_screen.dart';
import 'package:sponify/shared/widgets/artwork_image.dart';

import 'helpers/fixed_notifiers.dart';

Song _song(int i) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista $i',
  durationMs: 200000,
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

  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Stream<PlayerSnapshot> get snapshots => const Stream.empty();

  @override
  PlayerSnapshot get current => const PlayerSnapshot();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final queue = [_song(0), _song(1), _song(2)];

  Future<_FakeAudio> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final audio = _FakeAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              PlayerSnapshot(
                currentSong: queue[1],
                queue: queue,
                currentIndex: 1,
                isPlaying: true,
                status: PlaybackStatus.ready,
              ),
            ),
          ),
          likedSongsProvider.overrideWith(FixedLikedSongs.new),
          downloadedSongsProvider.overrideWith(FixedDownloads.new),
          downloadTasksProvider.overrideWith((ref) => Stream.value(const {})),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return audio;
  }

  Future<void> expirePending(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3));

  testWidgets('fling on the artwork skips to the next song', (tester) async {
    final audio = await pumpScreen(tester);

    await tester.fling(find.byType(ArtworkImage), const Offset(-250, 0), 1500);
    await tester.pumpAndSettle();
    await expirePending(tester);

    expect(audio.next, 1);
  });

  // Antes solo la carátula escuchaba el gesto: deslizar sobre el título o
  // el hueco de alrededor no hacía nada.
  testWidgets('fling on the title zone also changes song', (tester) async {
    final audio = await pumpScreen(tester);

    await tester.fling(find.text('Artista 1'), const Offset(-250, 0), 1500);
    await tester.pumpAndSettle();
    await expirePending(tester);
    await tester.fling(find.text('Canción 1'), const Offset(250, 0), 1500);
    await tester.pumpAndSettle();
    await expirePending(tester);

    expect(audio.next, 1);
    expect(audio.skippedTo, [0]);
    expect(audio.previous, 0);
  });

  testWidgets('dragging previews the neighbour artwork, title and artist', (
    tester,
  ) async {
    await pumpScreen(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ArtworkImage)),
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Canción 2'), findsOneWidget);
    expect(find.text('Artista 2'), findsOneWidget);
    expect(find.byType(ArtworkImage), findsNWidgets(2));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Canción 2'), findsNothing);
  });

  testWidgets('dragging the seek bar seeks and never skips', (tester) async {
    final audio = await pumpScreen(tester);

    await tester.drag(find.byType(Slider), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(audio.seeks, isNotEmpty);
    expect(audio.next, 0);
    expect(audio.skippedTo, isEmpty);
  });
}
