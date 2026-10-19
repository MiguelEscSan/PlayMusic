import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/playback_source.dart';
import 'package:koda/core/data/models/song_model.dart';
import 'package:koda/core/data/repositories/song_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/di/providers.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/settings/settings_dao.dart';
import 'package:koda/core/storage/file_paths.dart';
import 'package:koda/features/downloads/data/download_manager.dart';
import 'package:koda/features/downloads/presentation/downloads_screen.dart';
import 'package:koda/features/favorites/presentation/favorites_providers.dart';
import 'package:koda/features/favorites/presentation/like_button.dart';
import 'package:koda/features/history/data/history_dao.dart';
import 'package:koda/features/settings/presentation/settings_screen.dart';
import 'package:koda/shared/widgets/download_button.dart';
import 'package:koda/shared/widgets/error_view.dart';
import 'package:koda/shared/widgets/song_tile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_services.dart';
import 'domain/fakes/fake_song_repository.dart';
import 'helpers/fixed_notifiers.dart';

class _NoNetworkResolver implements PlaybackSourceResolver {
  @override
  Future<PlaybackSource> resolve(Song song, {bool forceRefresh = false}) =>
      throw SongUnavailableException(song, 'test');
}

Song _song(String id) => Song(
  id: '',
  title: 'Canción $id',
  artist: 'Artista',
  durationMs: 180000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Feedback de error de la UI: cuando un repositorio devuelve `Err`, la
/// pantalla muestra un [ErrorView] con "Reintentar" (carga) o un SnackBar
/// (mutación), en vez de fallar en silencio.
void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late AppDatabase db;
  late SongDao songDao;
  late SettingsDao settings;
  late FlakySongRepository songs;
  late DownloadManager downloads;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('koda_errors');
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    settings = SettingsDao(db);
    songs = FlakySongRepository(SongRepositoryImpl(songDao));
    // El gestor de descargas usa el mismo repositorio inestable, así un
    // `Err` de la BD llega también a los borrados.
    downloads = DownloadManager(
      dio: Dio(),
      songRepository: songs,
      paths: FilePaths(tmp),
      resolver: _NoNetworkResolver(),
    );
  });

  tearDown(() async {
    await downloads.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// Deja correr la BD (async real) y repinta.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  /// Como [settle], pero repite hasta que aparece [finder]: los borrados
  /// mezclan BD y disco y pueden tardar más de una vuelta.
  Future<void> settleUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songDaoProvider.overrideWithValue(songDao),
          songRepositoryProvider.overrideWithValue(songs),
          downloadServiceProvider.overrideWithValue(downloads),
          settingsDaoProvider.overrideWithValue(settings),
          historyDaoProvider.overrideWithValue(HistoryDao(db)),
          // `ToggleLikeUseCase` la necesita; aquí el "me gusta" falla antes.
          likedPlaylistProvider.overrideWithValue(FakeLikedPlaylistSync()),
          ...overrides,
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  /// Guarda una canción como descargada con un archivo real en disco.
  Future<Song> addDownloaded(WidgetTester tester, String id) async {
    final song = await tester.runAsync(() async {
      final saved = await songDao.upsert(SongModel.fromEntity(_song(id)));
      final file = File('${tmp.path}/${saved.id}.m4a')..writeAsBytesSync([1]);
      final marked = await songDao.markDownloaded(
        saved.id,
        localPath: file.path,
        sizeBytes: 1024,
      );
      return marked!.toEntity();
    });
    return song!;
  }

  /// Confirma el diálogo de borrado abierto y espera a [snack].
  Future<void> confirmAndWaitFor(
    WidgetTester tester,
    String confirmLabel,
    Finder snack,
  ) async {
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, confirmLabel));
    await settleUntil(tester, snack);
  }

  group('Descargas', () {
    testWidgets('un fallo al cargar muestra ErrorView y "Reintentar" recarga', (
      tester,
    ) async {
      await addDownloaded(tester, 'a');
      songs.getDownloadedFailures = 1;
      await pump(tester, const DownloadsScreen());

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('No se pudieron cargar las descargas'), findsOneWidget);
      expect(find.text('Canción a'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await settleUntil(tester, find.text('Canción a'));

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Canción a'), findsOneWidget);
    });

    testWidgets('si "Borrar todas" falla avisa con un SnackBar', (
      tester,
    ) async {
      await addDownloaded(tester, 'a');
      await pump(tester, const DownloadsScreen());
      songs.clearDownloadFailures = 1;

      await tester.tap(find.byTooltip('Borrar todas'));
      final snack = find.text('No se pudieron borrar todas las descargas');
      await confirmAndWaitFor(tester, 'Borrar todo', snack);

      expect(snack, findsOneWidget);
    });
  });

  testWidgets('Ajustes: si borrar las descargas falla avisa con un SnackBar', (
    tester,
  ) async {
    await addDownloaded(tester, 'a');
    await pump(tester, const SettingsScreen());
    songs.clearDownloadFailures = 1;

    final deleteAll = find.text('Borrar todas las descargas');
    await tester.ensureVisible(deleteAll);
    await tester.tap(deleteAll);
    final snack = find.text('No se pudieron borrar todas las descargas');
    await confirmAndWaitFor(tester, 'Borrar todo', snack);

    expect(snack, findsOneWidget);
  });

  testWidgets('DownloadButton: si borrar la descarga falla avisa', (
    tester,
  ) async {
    final song = await addDownloaded(tester, 'a');
    await pump(tester, Scaffold(body: DownloadButton(song: song)));
    songs.clearDownloadFailures = 1;

    await tester.tap(find.byTooltip('Descargada · toca para borrar'));
    final snack = find.text('No se pudo borrar la descarga');
    await confirmAndWaitFor(tester, 'Borrar', snack);

    expect(snack, findsOneWidget);
  });

  group('"Me gusta"', () {
    final snack = find.text('No se pudo actualizar "Me gusta"');

    // Favoritas fijas: el fallo no debe depender de recargar la lista.
    Future<void> pumpLiked(WidgetTester tester, Widget body) => pump(
      tester,
      Scaffold(body: body),
      overrides: [likedSongsProvider.overrideWith(FixedLikedSongs.new)],
    );

    testWidgets('LikeButton avisa si no se puede guardar', (tester) async {
      songs.setLikedFailures = 1;
      await pumpLiked(tester, LikeButton(song: _song('a')));

      await tester.tap(find.byTooltip('Me gusta'));
      await settleUntil(tester, snack);

      expect(snack, findsOneWidget);
      expect(find.byTooltip('Me gusta'), findsOneWidget);
      expect(await tester.runAsync(songDao.liked), isEmpty);
    });

    testWidgets('el menú de SongTile avisa si no se puede guardar', (
      tester,
    ) async {
      songs.setLikedFailures = 1;
      await pumpLiked(tester, SongTile(song: _song('a'), onTap: () {}));

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me gusta'));
      await settleUntil(tester, snack);

      expect(snack, findsOneWidget);
      expect(await tester.runAsync(songDao.liked), isEmpty);
    });
  });
}
