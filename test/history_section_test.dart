import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/history/presentation/history_providers.dart';
import 'package:sponify/features/history/presentation/recent_home_section.dart';
import 'package:sponify/shared/song_actions.dart';

Song _song(String id) => Song(
  id: id,
  title: 'Canción $id',
  artist: 'Artista $id',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Acciones falsas: solo recuerdan qué se pidió reproducir.
class _FakeActions implements SongActions {
  List<Song>? queue;
  int? index;

  @override
  Future<Result<Unit>> playQueue(List<Song> songs, int index) async {
    queue = songs;
    this.index = index;
    return const Ok(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late _FakeActions actions;

  setUp(() => actions = _FakeActions());

  Future<void> pump(WidgetTester tester, List<Song> recent) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentSongsProvider.overrideWith((ref) => Stream.value(recent)),
          songActionsProvider.overrideWithValue(actions),
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
    expect(actions.queue, recent);
    expect(actions.index, 1);
  });

  testWidgets('sin historial no pinta nada', (tester) async {
    await pump(tester, const []);
    expect(find.text('Escuchado recientemente'), findsNothing);
  });
}
