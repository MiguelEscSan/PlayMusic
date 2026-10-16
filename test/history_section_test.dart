import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/history/presentation/recent_home_section.dart';

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

  Future<void> pump(WidgetTester tester, List<Song> recent) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(
            FakeHistoryRepository(recent: recent),
          ),
          // Guardar devuelve la canción tal cual; el reproductor registra.
          songRepositoryProvider.overrideWithValue(
            FakeSongRepository()..saveResult = null,
          ),
          audioPlayerServiceProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: Scaffold(body: RecentHomeSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pinta el título y las canciones recientes', (tester) async {
    await pump(tester, [_song('1'), _song('2')]);
    expect(find.text('Escuchado recientemente'), findsOneWidget);
    expect(find.text('Canción 1'), findsOneWidget);
    // Cada canción es un SongTile: el subtítulo lleva artista y duración.
    expect(find.text('Artista 2 · 0:01'), findsOneWidget);
  });

  testWidgets('tocar una canción reproduce la lista desde ella', (
    tester,
  ) async {
    final recent = [_song('1'), _song('2')];
    await pump(tester, recent);
    await tester.tap(find.text('Canción 2'));
    await tester.pump();
    expect(audio.calls, ['playQueue([1,2], 1)']);
  });

  testWidgets('sin historial no pinta nada', (tester) async {
    await pump(tester, const []);
    expect(find.text('Escuchado recientemente'), findsNothing);
  });
}
