import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/player/presentation/player_providers.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/player/presentation/queue_sheet.dart';
import 'package:sponify/features/playlists/presentation/playlist_detail_screen.dart';
import 'package:sponify/features/export/domain/i_song_exporter.dart';
import 'package:sponify/shared/widgets/song_tile.dart';

import 'domain/fakes/fake_audio_player_service.dart';
import 'domain/fakes/fake_playlist_repository.dart';
import 'domain/fakes/fake_song_repository.dart';
import 'helpers/fixed_notifiers.dart';

Song _song(int i, {String? localPath}) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
  localPath: localPath,
);

class _FakeExporter implements ISongExporter {
  final exported = <Song>[];
  SongExportFailure? error;

  @override
  Future<Result<String>> export(Song song) async {
    if (error case final e?) return Err(e);
    exported.add(song);
    return const Ok('Music/Koda/x.m4a');
  }
}

/// Repositorio en memoria con una sola playlist; registra los quitar.
class _FakePlaylistRepository extends FakePlaylistRepository {
  _FakePlaylistRepository(this.playlist);

  Playlist playlist;
  final removed = <int>[];

  @override
  Future<Result<Playlist>> findById(String id) async => Ok(playlist);

  @override
  Future<Result<List<Playlist>>> getAll() async => Ok([playlist]);

  @override
  Future<Result<Unit>> removeSongAt(String playlistId, int index) async {
    removed.add(index);
    playlist = playlist.copyWith(songs: [...playlist.songs]..removeAt(index));
    return const Ok(unit);
  }
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
  late FakeAudioPlayerService player;
  late _FakeExporter exporter;

  setUp(() {
    exporter = _FakeExporter();
    player = FakeAudioPlayerService();
  });

  /// Encolar guarda la canción (tal cual) y la pasa al reproductor: [player]
  /// registra cada llamada, salvo que se pase otro [audio].
  List<Override> baseOverrides({
    PlayerSnapshot? snapshot,
    AudioPlayerService? audio,
  }) => [
    songRepositoryProvider.overrideWithValue(
      FakeSongRepository()..saveResult = null,
    ),
    audioPlayerServiceProvider.overrideWithValue(audio ?? player),
    songExporterProvider.overrideWithValue(exporter),
    playerSnapshotProvider.overrideWith(
      (ref) => snapshot == null
          ? const Stream<PlayerSnapshot>.empty()
          : Stream.value(snapshot),
    ),
    likedSongsProvider.overrideWith(FixedLikedSongs.new),
    downloadedSongsProvider.overrideWith(FixedDownloads.new),
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

      expect(player.calls, ['addToQueue(id0)']);
      expect(find.text('Añadida a la cola'), findsOneWidget);
      expect(find.text('Canción 0'), findsOneWidget);
    });

    testWidgets('deslizar a la izquierda no hace nada', (tester) async {
      await pumpTiles(tester, [_song(0)]);

      await tester.drag(find.text('Canción 0'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(player.calls, isEmpty);
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

      expect(player.calls, isEmpty);
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  group('playlist', () {
    testWidgets('derecha encola sin quitar; izquierda sigue quitando', (
      tester,
    ) async {
      // La cabecera (portada de 250) deja las filas fuera de los 600 px por
      // defecto: con una pantalla más alta se pueden arrastrar las dos.
      tester.view.physicalSize = const Size(2400, 4800);
      addTearDown(tester.view.resetPhysicalSize);
      final songs = [_song(0), _song(1)];
      final repository = _FakePlaylistRepository(
        Playlist(
          id: 'p1',
          name: 'Mi lista',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          songs: songs,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(),
            playlistRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: PlaylistDetailScreen(id: 'p1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Canción 0'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(player.calls, ['addToQueue(id0)']);
      expect(repository.removed, isEmpty);
      expect(find.text('Canción 0'), findsOneWidget);

      await tester.drag(find.text('Canción 1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(repository.removed, [1]);
      expect(find.text('Canción 1'), findsNothing);
      expect(player.calls, ['addToQueue(id0)']);
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
              audio: audio,
            ),
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
      exporter.error = SongExportFailure(SongExportError.permissionDenied);
      await pumpTiles(tester, [_song(0, localPath: '/data/music/id0.m4a')]);
      await openMenu(tester);

      await tester.tap(find.text('Exportar a Música'));
      await tester.pumpAndSettle();

      expect(
        find.text(SongExportFailure(SongExportError.permissionDenied).message),
        findsOneWidget,
      );
      expect(find.text('Guardada en Música/Koda'), findsNothing);
    });
  });
}
