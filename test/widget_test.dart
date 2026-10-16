import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/app.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/data/repositories/settings_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/history/data/history_dao.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sponify/features/radio/domain/radio_service.dart';
import 'package:sponify/features/search/data/search_history_dao.dart';
import 'package:sponify/features/search/domain/search_source.dart';
import 'package:sponify/features/search/domain/suggestion_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/liked_playlist_override.dart';

Song _song(String id, String title) => Song(
  id: '',
  title: title,
  artist: 'Artista $id',
  durationMs: 200000,
  source: SongSource.youtube,
  sourceId: id,
);

class _FakeSearch implements SearchSource {
  final queries = <String>[];

  @override
  Future<SearchPage> search(String query) async {
    queries.add(query);
    return SearchPage([_song('a', 'Primera'), _song('b', 'Segunda')], null);
  }
}

/// Sin sugerencias: los tests nunca tocan la red.
class _NoSuggestions implements SuggestionSource {
  @override
  Future<List<String>> suggestions(String query) async => const [];
}

/// Reproductor falso: guarda lo que se le pide y emite el estado.
class _FakeAudio implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _current = const PlayerSnapshot();
  List<Song>? lastQueue;
  int? lastIndex;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  PlayerSnapshot get current => _current;

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    lastQueue = songs;
    lastIndex = startIndex;
    _current = PlayerSnapshot(
      status: PlaybackStatus.ready,
      isPlaying: true,
      currentSong: songs[startIndex],
      queue: songs,
      currentIndex: startIndex,
    );
    _controller.add(_current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoNetworkResolver implements PlaybackSourceResolver {
  @override
  Future<PlaybackSource> resolve(Song song, {bool forceRefresh = false}) =>
      throw SongUnavailableException(song, 'test');
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SongDao songDao;
  late PlaylistDao playlistDao;
  late HistoryDao historyDao;
  late DownloadManager downloads;
  late _FakeAudio audio;
  late _FakeSearch search;
  late Directory tmp;

  setUp(() async {
    // sqflite_ffi corre en otro isolate; runAsync evita bloquear el reloj
    // falso de los tests de widgets.
    tmp = Directory.systemTemp.createTempSync('sponify_ui');
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    playlistDao = PlaylistDao(db, songDao);
    historyDao = HistoryDao(db);
    downloads = DownloadManager(
      dio: Dio(),
      songRepository: SongRepositoryImpl(songDao),
      paths: FilePaths(tmp),
      resolver: _NoNetworkResolver(),
    );
    audio = _FakeAudio();
    search = _FakeSearch();
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          songDaoProvider.overrideWithValue(songDao),
          playlistDaoProvider.overrideWithValue(playlistDao),
          downloadServiceProvider.overrideWithValue(downloads),
          historyDaoProvider.overrideWithValue(historyDao),
          settingsDaoProvider.overrideWithValue(SettingsDao(db)),
          likedPlaylistFromRepositories,
          searchSourceProvider.overrideWithValue(search),
          searchHistoryDaoProvider.overrideWithValue(SearchHistoryDao(db)),
          suggestionSourceProvider.overrideWithValue(_NoSuggestions()),
          radioServiceProvider.overrideWithValue(
            RadioService(
              fetchRelated: (_) async => const [],
              songRepository: SongRepositoryImpl(songDao),
              settings: SettingsRepositoryImpl(SettingsDao(db)),
            ),
          ),
        ],
        child: const SponifyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Deja correr la BD (async real) y repinta.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  /// Como [settle], pero repite hasta que aparece [finder]: con toda la
  /// suite en paralelo, la recarga tras una escritura puede tardar más de
  /// una vuelta.
  Future<void> settleUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  testWidgets('la app arranca en Inicio', (tester) async {
    await pumpApp(tester);
    expect(find.widgetWithText(AppBar, 'Inicio'), findsOneWidget);
    // Sin favoritas ni historial se ve el estado vacío, no una pantalla en
    // blanco.
    expect(find.text('Aquí aparecerá tu música'), findsOneWidget);
    expect(find.text('Te gusta'), findsNothing);
    expect(find.text('Escuchado recientemente'), findsNothing);
  });

  testWidgets('"Me gusta" en un resultado lo añade a "Me encanta" en Inicio', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Buscar'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'rosalia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    await tester.tap(find.byTooltip('Más opciones').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me gusta'));
    await settle(tester);

    final liked = await tester.runAsync(songDao.liked);
    expect([for (final s in liked!) s.title], ['Segunda']);

    // Inicio ya no tiene sección "Te gusta": las favoritas viven en la
    // playlist "Me encanta", que aparece entre las playlists de Inicio.
    await tester.tap(find.text('Inicio'));
    await settleUntil(tester, find.text('Me encanta'));
    expect(find.text('Te gusta'), findsNothing);
    expect(find.text('Me encanta'), findsOneWidget);
    expect(find.text('1 canción'), findsOneWidget);
  });

  testWidgets('lo escuchado aparece en Inicio', (tester) async {
    await pumpApp(tester);
    // El DAO ya no avisa por sí solo: quien escribe (el `HistoryRecorder`
    // en la app) lo anuncia en `HistoryEvents` y las listas se recargan.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    await tester.runAsync(() async {
      final song = await songDao.upsert(
        SongModel.fromEntity(_song('r', 'Reciente')),
      );
      await historyDao.record(song.id);
    });
    container.read(historyEventsProvider).announce();
    await settle(tester);
    expect(find.text('Escuchado recientemente'), findsOneWidget);
    expect(find.text('Reciente'), findsOneWidget);
  });

  testWidgets('buscar y tocar un resultado lo reproduce', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Buscar'));
    await settle(tester);
    expect(find.text('Busca cualquier canción'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'rosalia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(search.queries, ['rosalia']);
    expect(find.text('Primera'), findsOneWidget);
    expect(find.text('Segunda'), findsOneWidget);

    await tester.tap(find.text('Segunda'));
    await settle(tester);

    // Suena solo la tocada (detrás irá la radio), no todos los resultados.
    expect(audio.lastIndex, 0);
    expect([for (final s in audio.lastQueue!) s.title], ['Segunda']);
    expect(
      audio.lastQueue!.single.id,
      isNotEmpty,
      reason: 'se guarda en la BD antes de sonar',
    );
    // Aparece el mini-reproductor con la canción.
    expect(find.text('Segunda'), findsNWidgets(2));
  });

  testWidgets('crear una playlist desde la pestaña Playlists', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Playlists'));
    await settle(tester);
    expect(find.text('Aún no tienes playlists'), findsOneWidget);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Para correr');
    await tester.tap(find.text('Crear'));
    await settle(tester);

    // Se abre el detalle de la playlist recién creada, vacía.
    expect(find.text('Para correr'), findsOneWidget);
    expect(find.text('Playlist vacía'), findsOneWidget);

    // Las escrituras pasan por el notifier, que refresca lista y detalle (la
    // BD ya no avisa de los cambios por sí sola).
    final container = ProviderScope.containerOf(
      tester.element(find.text('Playlist vacía')),
    );
    await tester.runAsync(() async {
      final p = (await playlistDao.all()).single;
      await container
          .read(playlistsProvider.notifier)
          .addSong(p.id, _song('x', 'Canción X'));
    });
    await settleUntil(tester, find.text('Canción X'));
    expect(find.text('Canción X'), findsOneWidget);
    expect(find.text('1 canción · 3:20'), findsOneWidget);
  });

  testWidgets('Ajustes se abre desde Inicio con sus secciones', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Ajustes'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
    expect(find.text('Radio automática'), findsOneWidget);
    expect(find.text('0 KB · 0 canciones'), findsOneWidget);
  });

  testWidgets('Descargas vacía muestra el estado inicial', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Descargas'));
    await settle(tester);
    expect(find.text('Sin descargas'), findsOneWidget);
  });
}
