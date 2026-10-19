import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/features/player/presentation/player_providers.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/lyrics/domain/i_lyrics_repository.dart';
import 'package:koda/features/lyrics/domain/lyrics.dart';
import 'package:koda/features/lyrics/presentation/lyrics_screen.dart';

/// Repositorio falso: cada llamada consume la siguiente respuesta preparada.
/// Una respuesta que lanza se devuelve como `Err(NetworkFailure)`.
class _FakeRepo implements ILyricsRepository {
  _FakeRepo(this.responses);

  final List<Future<Lyrics> Function()> responses;
  final requested = <(String, String)>[];

  @override
  Future<Result<Lyrics>> getLyrics(
    String title,
    String artist, {
    int durationSeconds = 0,
  }) async {
    requested.add((title, artist));
    try {
      return Ok(await responses.removeAt(0)());
    } on Exception catch (e) {
      return Err(NetworkFailure('$e', cause: e));
    }
  }
}

class _FakeAudio implements AudioPlayerService {
  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _songA = Song(
  id: 'a',
  title: 'Canción A',
  artist: 'Artista',
  durationMs: 180000,
  source: SongSource.youtube,
  sourceId: 'a',
);

const _songB = Song(
  id: 'b',
  title: 'Canción B',
  artist: 'Artista',
  durationMs: 180000,
  source: SongSource.youtube,
  sourceId: 'b',
);

void main() {
  late StreamController<PlayerSnapshot> snapshots;
  late StreamController<Duration> positions;
  late _FakeAudio audio;

  setUp(() {
    snapshots = StreamController<PlayerSnapshot>.broadcast();
    positions = StreamController<Duration>.broadcast();
    audio = _FakeAudio();
  });

  tearDown(() async {
    await snapshots.close();
    await positions.close();
  });

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerSnapshotProvider.overrideWith((ref) => snapshots.stream),
          playerPositionProvider.overrideWith((ref) => positions.stream),
          lyricsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: LyricsScreen()),
      ),
    );
    snapshots.add(const PlayerSnapshot(currentSong: _songA));
    await tester.pump();
  }

  testWidgets('muestra carga y luego la letra en texto plano', (tester) async {
    final completer = Completer<Lyrics>();
    await pump(tester, _FakeRepo([() => completer.future]));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const PlainLyrics('Verso uno\nVerso dos'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Verso uno\nVerso dos'), findsOneWidget);
  });

  testWidgets('canción instrumental', (tester) async {
    await pump(tester, _FakeRepo([() async => const InstrumentalLyrics()]));
    await tester.pump();
    expect(find.text('Canción instrumental'), findsOneWidget);
  });

  testWidgets('sin letra', (tester) async {
    await pump(tester, _FakeRepo([() async => const LyricsNotFound()]));
    await tester.pump();
    expect(find.text('No hay letra para esta canción'), findsOneWidget);
  });

  testWidgets('error con reintento', (tester) async {
    final repo = _FakeRepo([
      () async => throw Exception('sin red'),
      () async => const PlainLyrics('Ya cargó'),
    ]);
    await pump(tester, repo);
    await tester.pump();

    expect(find.text('No se pudo cargar la letra'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ya cargó'), findsOneWidget);
    expect(repo.requested, [
      (_songA.title, _songA.artist),
      (_songA.title, _songA.artist),
    ]);
  });

  testWidgets('sincronizada: resalta la línea actual y busca al tocar', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeRepo([
        () async => const SyncedLyrics([
          LyricLine(Duration(seconds: 1), 'Primera'),
          LyricLine(Duration(seconds: 5), 'Segunda'),
          LyricLine(Duration(seconds: 9), 'Tercera'),
        ]),
      ]),
    );
    await tester.pump();

    LyricLineTile tile(String text) =>
        tester.widget<LyricLineTile>(find.widgetWithText(LyricLineTile, text));

    positions.add(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(tile('Segunda').isActive, isTrue);
    expect(tile('Primera').isActive, isFalse);
    expect(tile('Tercera').isActive, isFalse);

    await tester.tap(find.text('Tercera'));
    await tester.pump();
    expect(audio.seeks, [const Duration(seconds: 9)]);
  });

  testWidgets('sigue a la canción actual cuando cambia', (tester) async {
    final repo = _FakeRepo([
      () async => const PlainLyrics('Letra A'),
      () async => const PlainLyrics('Letra B'),
    ]);
    await pump(tester, repo);
    await tester.pump();
    expect(find.text('Letra A'), findsOneWidget);

    snapshots.add(const PlayerSnapshot(currentSong: _songB));
    await tester.pump();
    await tester.pump();

    expect(find.text('Letra B'), findsOneWidget);
    expect(find.text('Canción B'), findsOneWidget);
    expect(repo.requested, [
      (_songA.title, _songA.artist),
      (_songB.title, _songB.artist),
    ]);
  });

  testWidgets('sin canción sonando', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          playerSnapshotProvider.overrideWith((ref) => snapshots.stream),
          playerPositionProvider.overrideWith((ref) => positions.stream),
          lyricsRepositoryProvider.overrideWithValue(_FakeRepo([])),
        ],
        child: const MaterialApp(home: LyricsScreen()),
      ),
    );
    snapshots.add(const PlayerSnapshot());
    await tester.pump();
    expect(find.text('No hay nada sonando'), findsOneWidget);
  });
}
