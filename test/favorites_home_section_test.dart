import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/features/player/presentation/player_providers.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/features/favorites/presentation/favorites_providers.dart';
import 'package:koda/features/favorites/presentation/liked_home_section.dart';

import 'helpers/fixed_notifiers.dart';

Song _song(int i) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
  likedAt: DateTime(2026, 1, i + 1),
);

Future<void> _pump(WidgetTester tester, List<Song> liked) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        likedSongsProvider.overrideWith(() => FixedLikedSongs(liked)),
        playerSnapshotProvider.overrideWith(
          (ref) => const Stream<PlayerSnapshot>.empty(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: LikedHomeSection())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin favoritas no pinta nada', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Te gusta'), findsNothing);
  });

  testWidgets('muestra el contador y como mucho 5 canciones', (tester) async {
    await _pump(tester, [for (var i = 0; i < 7; i++) _song(i)]);
    expect(find.text('Te gusta'), findsOneWidget);
    expect(find.text('7 canciones'), findsOneWidget);
    expect(find.text('Canción 0'), findsOneWidget);
    expect(find.text('Canción 4'), findsOneWidget);
    expect(find.text('Canción 5'), findsNothing);
    expect(find.text('Ver todas'), findsOneWidget);
  });

  testWidgets('"Ver todas" abre la lista completa', (tester) async {
    await _pump(tester, [for (var i = 0; i < 7; i++) _song(i)]);
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(find.text('Canciones que te gustan'), findsOneWidget);
    expect(find.text('Canción 6'), findsOneWidget);
  });
}
