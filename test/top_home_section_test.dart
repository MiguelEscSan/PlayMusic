import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/history/presentation/top_home_section.dart';

import 'domain/fakes/fake_audio_player_service.dart';
import 'domain/fakes/fake_feature_repositories.dart';
import 'domain/fakes/fake_song_repository.dart';

Song _song(String id) => Song(
  id: id,
  title: 'Canción $id',
  artist: 'Artista $id',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

void main() {
  late FakeAudioPlayerService audio;

  setUp(() => audio = FakeAudioPlayerService());

  Future<void> pump(WidgetTester tester, List<Song> top) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(
            FakeHistoryRepository(top: top),
          ),
          // Guardar devuelve la canción tal cual; el reproductor registra.
          songRepositoryProvider.overrideWithValue(
            FakeSongRepository()..saveResult = null,
          ),
          audioPlayerServiceProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: Scaffold(body: TopHomeSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pinta el título y el recuento del top', (tester) async {
    await pump(tester, [_song('1'), _song('2')]);
    expect(find.text('Tu top del mes'), findsOneWidget);
    expect(find.text('2 canciones · últimos 30 días'), findsOneWidget);
  });

  testWidgets('Reproducir pone en cola el top entero desde el primero', (
    tester,
  ) async {
    final top = [_song('1'), _song('2')];
    await pump(tester, top);
    await tester.tap(find.text('Reproducir'));
    await tester.pump();
    expect(audio.calls, ['playQueue([1,2], 0)']);
  });

  testWidgets('sin escuchas no pinta nada', (tester) async {
    await pump(tester, const []);
    expect(find.text('Tu top del mes'), findsNothing);
  });
}
