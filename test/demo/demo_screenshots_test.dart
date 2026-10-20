import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/domain/entities/playlist.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/downloads/presentation/downloads_providers.dart';
import 'package:koda/features/downloads/presentation/downloads_notifier.dart';
import 'package:koda/features/favorites/presentation/favorites_providers.dart';
import 'package:koda/features/history/presentation/history_providers.dart';
import 'package:koda/features/home/home_shell.dart';
import 'package:koda/features/player/presentation/mini_player.dart';
import 'package:koda/features/player/presentation/player_providers.dart';
import 'package:koda/features/playlists/presentation/playlists_notifier.dart';
import 'package:koda/features/search/presentation/search_controller.dart';
import 'package:koda/features/search/presentation/search_history_providers.dart';
import 'package:koda/features/search/presentation/search_suggestions_controller.dart';
import 'package:koda/features/settings/presentation/settings_notifier.dart';
import 'package:koda/features/settings/presentation/settings_providers.dart';

import '../helpers/fixed_notifiers.dart';

/// Genera los frames del recorrido de la demo del README en
/// `build/demo_frames`. Todo es ficticio: títulos inventados, carátulas
/// generadas por la app y datos de prueba. Después se codifican a MP4 y GIF
/// con ffmpeg (ver README).
///
/// Regenerar: `flutter test test/demo`
const _fontPath = r'C:\Windows\Fonts\segoeui.ttf';
const _iconsPath =
    r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf';
const _framesDir = 'build/demo_frames';

final _boundaryKey = GlobalKey();
int _frame = 0;

List<Song> _songs() => const [
  Song(
    id: 'd1',
    title: 'Noche de Luna',
    artist: 'Banda Ejemplo',
    durationMs: 214000,
    source: SongSource.youtube,
    sourceId: 'd1',
    fileSizeBytes: 5200000,
  ),
  Song(
    id: 'd2',
    title: 'Ciudad Azul',
    artist: 'Trío Demo',
    durationMs: 187000,
    source: SongSource.youtube,
    sourceId: 'd2',
    fileSizeBytes: 4600000,
  ),
  Song(
    id: 'd3',
    title: 'Amanecer Corto',
    artist: 'Artista Prueba',
    durationMs: 162000,
    source: SongSource.youtube,
    sourceId: 'd3',
    fileSizeBytes: 4100000,
  ),
  Song(
    id: 'd4',
    title: 'Río en Calma',
    artist: 'Orquesta Imaginaria',
    durationMs: 201000,
    source: SongSource.youtube,
    sourceId: 'd4',
    fileSizeBytes: 4900000,
  ),
  Song(
    id: 'd5',
    title: 'Brisa de Verano',
    artist: 'Coro Ficticio',
    durationMs: 175000,
    source: SongSource.youtube,
    sourceId: 'd5',
  ),
  Song(
    id: 'd6',
    title: 'Mapa Sin Rumbo',
    artist: 'Grupo Inventado',
    durationMs: 193000,
    source: SongSource.youtube,
    sourceId: 'd6',
  ),
];

List<Playlist> _playlists(List<Song> songs) => [
  Playlist(
    id: 'p1',
    name: 'Mix de prueba',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
    songs: songs.take(3).toList(),
  ),
  Playlist(
    id: 'p2',
    name: 'Para estudiar',
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 5),
    songs: songs.skip(2).take(4).toList(),
  ),
];

class _DemoAudio implements AudioPlayerService {
  @override
  Stream<PlayerSnapshot> get snapshots => const Stream.empty();

  @override
  PlayerSnapshot get current => const PlayerSnapshot();

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedTop extends TopSongsNotifier {
  _FixedTop(this.songs);

  final List<Song> songs;

  @override
  Future<List<Song>> build() async => songs;
}

class _FixedRecent extends RecentSongsNotifier {
  _FixedRecent(this.songs);

  final List<Song> songs;

  @override
  Future<List<Song>> build() async => songs;
}

class _FixedPlaylists extends PlaylistsNotifier {
  _FixedPlaylists(this.playlists);

  final List<Playlist> playlists;

  @override
  Future<List<Playlist>> build() async => playlists;
}

class _FixedSearch extends SongSearchController {
  _FixedSearch(this.results);

  final List<Song> results;

  @override
  SearchState build() => SearchState(query: 'lluvia', results: results);
}

class _FixedSuggestions extends SearchSuggestionsController {
  @override
  List<String> build() => const ['lluvia', 'luna', 'verano'];
}

class _FixedRecentSearches extends RecentSearchesNotifier {
  @override
  Future<List<String>> build() async => const ['río', 'brisa'];
}

class _FixedSettings extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

Future<ByteData> _fontFile(String path) async =>
    ByteData.sublistView(File(path).readAsBytesSync());

Future<void> _loadFont() async {
  final text = FontLoader('Segoe UI')..addFont(_fontFile(_fontPath));
  final icons = FontLoader('MaterialIcons')..addFont(_fontFile(_iconsPath));
  await text.load();
  await icons.load();
}

/// Captura [frames] imágenes de la app, con [step] de avance entre ellas.
Future<void> _capture(
  WidgetTester tester, {
  int frames = 6,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundaryKey),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final name = (_frame++).toString().padLeft(3, '0');
      File(
        '$_framesDir/frame_$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    });
  }
}

/// Toca una pestaña de la barra inferior.
Future<void> _goTo(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'recorrido por las pantallas de la app',
    skip: !File(_fontPath).existsSync(),
    (tester) async {
      await _loadFont();
      final dir = Directory(_framesDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      _frame = 0;

      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final songs = _songs();
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      final snapshot = PlayerSnapshot(
        currentSong: songs[0],
        queue: songs,
        currentIndex: 0,
        isPlaying: true,
        status: PlaybackStatus.ready,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(_DemoAudio()),
            playerSnapshotProvider.overrideWith(
              (ref) => Stream.value(snapshot),
            ),
            playerPositionProvider.overrideWith((ref) => positions.stream),
            likedSongsProvider.overrideWith(
              () => FixedLikedSongs(songs.take(3).toList()),
            ),
            downloadedSongsProvider.overrideWith(
              () => FixedDownloads(songs.take(4).toList()),
            ),
            downloadTasksProvider.overrideWith(
              (ref) => Stream.value(const {}),
            ),
            topSongsProvider.overrideWith(() => _FixedTop(songs)),
            recentSongsProvider.overrideWith(
              () => _FixedRecent(songs.reversed.toList()),
            ),
            playlistsProvider.overrideWith(
              () => _FixedPlaylists(_playlists(songs)),
            ),
            searchControllerProvider.overrideWith(
              () => _FixedSearch(songs.take(4).toList()),
            ),
            searchSuggestionsProvider.overrideWith(
              _FixedSuggestions.new,
            ),
            recentSearchesProvider.overrideWith(
              _FixedRecentSearches.new,
            ),
            settingsProvider.overrideWith(_FixedSettings.new),
            storageUsageProvider.overrideWith(
              (ref) => (bytes: 73400320, songs: 4),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF1DB954),
              brightness: Brightness.dark,
              fontFamily: 'Segoe UI',
            ),
            builder: (context, child) => RepaintBoundary(
              key: _boundaryKey,
              child: child!,
            ),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Inicio
      await _capture(tester, frames: 12);

      // Buscar
      await _goTo(tester, 'Buscar');
      await _capture(tester, frames: 8);

      // Playlists
      await _goTo(tester, 'Playlists');
      await _capture(tester, frames: 8);

      // Descargas
      await _goTo(tester, 'Descargas');
      await _capture(tester, frames: 8);

      // Reproductor, desde la barra inferior
      await _goTo(tester, 'Inicio');
      await tester.tap(find.byType(MiniPlayer));
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 24; i++) {
        positions.add(Duration(seconds: i * 9));
        await _capture(tester, frames: 1);
      }
    },
  );
}
