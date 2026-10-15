import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/audio_providers.dart';
import 'package:sponify/core/models/playlist.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/player/presentation/queue_sheet.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/features/playlists/presentation/playlist_detail_screen.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sponify/shared/export/song_exporter.dart';
import 'package:sponify/shared/song_actions.dart';
import 'package:sponify/shared/widgets/song_tile.dart';

Song _song(int i, {String? localPath}) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
  localPath: localPath,
);

/// Acciones falsas: registran lo que se pide sin tocar BD ni audio.
class _FakeActions extends SongActions {
  _FakeActions(super.ref);

  final queued = <Song>[];

  @override
  Future<void> addToQueue(Song song) async => queued.add(song);
}

class _FakeExporter implements SongExporter {
  final exported = <Song>[];
  SongExportException? error;

  @override
  Future<String> export(Song song) async {
    if (error != null) throw error!;
    exported.add(song);
    return 'Music/Koda/x.m4a';
  }
}

class _FakePlaylistDao implements PlaylistDao {
  final removed = <int>[];

  @override
  Future<void> removeAt(String playlistId, int index) async =>
      removed.add(index);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudio implements AudioPlayerService {
  final removed = <int>[];
  final added = <Song>[];

  @override
  Future<void> removeFromQueue(int index) async => removed.add(index);

  @override
  Future<void> addToQueue(Song song) async => added.add(song);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  _FakeActions? actions;
  late _FakeExporter exporter;

  setUp(() {
    exporter = _FakeExporter();
    actions = null;
  });

  List<Override> baseOverrides({PlayerSnapshot? snapshot}) => [
    songActionsProvider.overrideWith((ref) => actions = _FakeActions(ref)),
    songExporterProvider.overrideWithValue(exporter),
    playerSnapshotProvider.overrideWith(
      (ref) => snapshot == null
          ? const Stream<PlayerSnapshot>.empty()
          : Stream.value(snapshot),
    ),
    likedSongsProvider.overrideWith((ref) => Stream.value(const [])),
    downloadedSongsProvider.overrideWith((ref) => Stream.value(const [])),
    downloadTasksProvider.overrideWith((ref) => Stream.value(const {})),
  ];

  Future<void> pumpTiles(WidgetTester tester, List<Song> songs) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final s in songs) SongTile(song: s, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('deslizar a la derecha', () {
    testWidgets('añade a la cola, avisa y la fila vuelve a su sitio', (
      tester,
    ) async {
      final song = _song(0);
      await pumpTiles(tester, [song]);

      await tester.drag(find.text('Canción 0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(actions!.queued, [song]);
      expect(find.text('Añadida a la cola'), findsOneWidget);
      expect(find.text('Canción 0'), findsOneWidget);
    });

    testWidgets('deslizar a la izquierda no hace nada', (tester) async {
      await pumpTiles(tester, [_song(0)]);

      await tester.drag(find.text('Canción 0'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(actions?.queued ?? const [], isEmpty);
      expect(find.text('Añadida a la cola'), findsNothing);
    });

    testWidgets('se puede desactivar con swipeToQueue: false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: SongTile(song: _song(0), onTap: () {}, swipeToQueue: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Canción 0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(actions?.queued ?? const [], isEmpty);
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  group('playlist', () {
    testWidgets('derecha encola sin quitar; izquierda sigue quitando', (
      tester,
    ) async {
      final dao = _FakePlaylistDao();
      final songs = [_song(0), _song(1)];
      final playlist = Playlist(
        id: 'p1',
        name: 'Mi lista',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        songs: songs,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(),
            playlistDaoProvider.overrideWithValue(dao),
            playlistProvider.overrideWith((ref, id) => Stream.value(playlist)),
          ],
          child: const MaterialApp(home: PlaylistDetailScreen(id: 'p1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Canción 0'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(actions!.queued, [songs[0]]);
      expect(dao.removed, isEmpty);
      expect(find.text('Canción 0'), findsOneWidget);

      await tester.drag(find.text('Canción 1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(dao.removed, [1]);
      expect(find.text('Canción 1'), findsNothing);
      expect(actions!.queued, [songs[0]]);
    });
  });

  group('cola', () {
    testWidgets('derecha no hace nada; izquierda sigue quitando', (
      tester,
    ) async {
      final audio = _FakeAudio();
      final queue = [_song(0), _song(1)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              snapshot: PlayerSnapshot(queue: queue, currentSong: queue[0]),
            ),
            audioPlayerServiceProvider.overrideWithValue(audio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showQueueSheet(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Canción 1'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(audio.added, isEmpty);
      expect(actions?.queued ?? const [], isEmpty);
      expect(audio.removed, isEmpty);

      await tester.drag(find.text('Canción 1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(audio.removed, [1]);
    });
  });

  group('exportar', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
    }

    testWidgets('no aparece si la canción no está descargada', (tester) async {
      await pumpTiles(tester, [_song(0)]);
      await openMenu(tester);
      expect(find.text('Añadir a la cola'), findsOneWidget);
      expect(find.text('Exportar a Música'), findsNothing);
    });

    testWidgets('aparece si está descargada y exporta', (tester) async {
      final song = _song(0, localPath: '/data/music/id0.m4a');
      await pumpTiles(tester, [song]);
      await openMenu(tester);

      await tester.tap(find.text('Exportar a Música'));
      await tester.pumpAndSettle();

      expect(exporter.exported, [song]);
      expect(find.text('Guardada en Música/Koda'), findsOneWidget);
    });

    testWidgets('si falla muestra el error en español', (tester) async {
      exporter.error = const SongExportException(
        SongExportError.permissionDenied,
      );
      await pumpTiles(tester, [_song(0, localPath: '/data/music/id0.m4a')]);
      await openMenu(tester);

      await tester.tap(find.text('Exportar a Música'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          const SongExportException(SongExportError.permissionDenied).message,
        ),
        findsOneWidget,
      );
      expect(find.text('Guardada en Música/Koda'), findsNothing);
    });
  });
}
