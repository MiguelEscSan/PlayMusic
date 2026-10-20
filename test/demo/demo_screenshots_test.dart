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
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/downloads/presentation/downloads_providers.dart';
import 'package:koda/features/favorites/presentation/favorites_providers.dart';
import 'package:koda/features/player/presentation/now_playing_screen.dart';
import 'package:koda/features/player/presentation/player_providers.dart';

import '../helpers/fixed_notifiers.dart';

/// Genera los frames de la demo del README en `build/demo_frames`. No usa
/// canciones ni carátulas reales: títulos inventados y carátulas generadas
/// por la app. Después se codifican a video con ffmpeg (ver README).
///
/// Regenerar: `flutter test test/demo`
const _fontPath = r'C:\Windows\Fonts\segoeui.ttf';
const _iconsPath =
    r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf';
const _frames = 120;
const _framesDir = 'build/demo_frames';
final _boundaryKey = GlobalKey();

final _queue = [
  const Song(
    id: 'demo-1',
    title: 'Noche de Luna',
    artist: 'Banda Ejemplo',
    durationMs: 214000,
    source: SongSource.youtube,
    sourceId: 'demo-1',
  ),
  const Song(
    id: 'demo-2',
    title: 'Ciudad Azul',
    artist: 'Trío Demo',
    durationMs: 187000,
    source: SongSource.youtube,
    sourceId: 'demo-2',
  ),
  const Song(
    id: 'demo-3',
    title: 'Amanecer Corto',
    artist: 'Artista Prueba',
    durationMs: 162000,
    source: SongSource.youtube,
    sourceId: 'demo-3',
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

Future<void> _loadFont() async {
  final text = FontLoader('Segoe UI')
    ..addFont(_fontFile(_fontPath));
  final icons = FontLoader('MaterialIcons')
    ..addFont(_fontFile(_iconsPath));
  await text.load();
  await icons.load();
}

Future<ByteData> _fontFile(String path) async =>
    ByteData.sublistView(File(path).readAsBytesSync());

void main() {
  testWidgets(
    'capturas de la pantalla de reproducción',
    skip: !File(_fontPath).existsSync(),
    (tester) async {
      await _loadFont();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(_DemoAudio()),
            playerSnapshotProvider.overrideWith(
              (ref) => Stream.value(
                PlayerSnapshot(
                  currentSong: _queue[0],
                  queue: _queue,
                  currentIndex: 0,
                  isPlaying: true,
                  status: PlaybackStatus.ready,
                ),
              ),
            ),
            playerPositionProvider.overrideWith((ref) => positions.stream),
            likedSongsProvider.overrideWith(FixedLikedSongs.new),
            downloadedSongsProvider.overrideWith(FixedDownloads.new),
            downloadTasksProvider.overrideWith(
              (ref) => Stream.value(const {}),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF1DB954),
              brightness: Brightness.dark,
              fontFamily: 'Segoe UI',
            ),
            home: RepaintBoundary(
              key: _boundaryKey,
              child: const NowPlayingScreen(),
            ),
          ),
        ),
      );

      Directory(_framesDir).createSync(recursive: true);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundaryKey),
      );

      for (var i = 0; i < _frames; i++) {
        positions.add(Duration(milliseconds: i * 1750));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = i.toString().padLeft(3, '0');
          File(
            '$_framesDir/frame_$name.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
    },
  );
}
