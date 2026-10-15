import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/history/presentation/history_providers.dart';
import 'package:sponify/features/history/presentation/top_home_section.dart';
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
  Future<void> playQueue(List<Song> songs, int index) async {
    queue = songs;
    this.index = index;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late _FakeActions actions;

  setUp(() => actions = _FakeActions());

  Future<void> pump(WidgetTester tester, List<Song> top) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topSongsProvider.overrideWith((ref) => Stream.value(top)),
          songActionsProvider.overrideWithValue(actions),
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
    expect(actions.queue, top);
    expect(actions.index, 0);
  });

  testWidgets('sin escuchas no pinta nada', (tester) async {
    await pump(tester, const []);
    expect(find.text('Tu top del mes'), findsNothing);
  });
}
