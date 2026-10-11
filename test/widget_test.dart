import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/app.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/audio_providers.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sponify/features/search/data/search_source.dart';
import 'package:sponify/features/search/presentation/search_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    downloads = DownloadManager(
      dio: Dio(),
      songDao: songDao,
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
          downloadManagerProvider.overrideWithValue(downloads),
          searchSourceProvider.overrideWithValue(search),
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

  testWidgets('buscar y tocar un resultado lo reproduce', (tester) async {
    await pumpApp(tester);
    expect(find.text('Busca cualquier canción'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'rosalia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(search.queries, ['rosalia']);
    expect(find.text('Primera'), findsOneWidget);
    expect(find.text('Segunda'), findsOneWidget);

    await tester.tap(find.text('Segunda'));
    await settle(tester);

    expect(audio.lastIndex, 1);
    expect(
      audio.lastQueue!.every((s) => s.id.isNotEmpty),
      isTrue,
      reason: 'se guardan en la BD antes de sonar',
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

    await tester.runAsync(() async {
      final p = (await playlistDao.all()).single;
      await playlistDao.addSong(p.id, _song('x', 'Canción X'));
    });
    await settle(tester);
    expect(find.text('Canción X'), findsOneWidget);
    expect(find.text('1 canción · 3:20'), findsOneWidget);
  });

  testWidgets('Descargas vacía muestra el estado inicial', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Descargas'));
    await settle(tester);
    expect(find.text('Sin descargas'), findsOneWidget);
  });
}
