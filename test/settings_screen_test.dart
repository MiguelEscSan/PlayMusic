import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/core/settings/settings_providers.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/history/data/history_dao.dart';
import 'package:sponify/features/history/presentation/history_providers.dart';
import 'package:sponify/features/settings/data/download_policy.dart';
import 'package:sponify/features/settings/presentation/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late AppDatabase db;
  late SongDao songDao;
  late HistoryDao historyDao;
  late SettingsDao settings;
  late DownloadManager downloads;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('sponify_settings');
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    historyDao = HistoryDao(db);
    settings = SettingsDao(db);
    downloads = DownloadManager(
      dio: Dio(),
      songRepository: SongRepositoryImpl(songDao),
      paths: FilePaths(tmp),
      resolver: _NoNetworkResolver(),
    );
  });

  tearDown(() async {
    await downloads.dispose();
    await settings.dispose();
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

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songDaoProvider.overrideWithValue(songDao),
          downloadManagerProvider.overrideWithValue(downloads),
          historyDaoProvider.overrideWithValue(historyDao),
          settingsDaoProvider.overrideWithValue(settings),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);
  }

  /// Guarda una canción como descargada con un archivo real en disco.
  Future<Song> addDownloaded(String id, int sizeBytes) async {
    final saved = await songDao.upsert(SongModel.fromEntity(_song(id)));
    final file = File('${tmp.path}/${saved.id}.m4a')..writeAsBytesSync([1]);
    final marked = await songDao.markDownloaded(
      saved.id,
      localPath: file.path,
      sizeBytes: sizeBytes,
    );
    return marked!.toEntity();
  }

  SwitchListTile switchTile(WidgetTester tester, String title) =>
      tester.widget(find.widgetWithText(SwitchListTile, title));

  testWidgets('los interruptores muestran y guardan los ajustes', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Reproducción'), findsOneWidget);
    expect(
      find.text('Al acabar la cola, sigue con canciones parecidas'),
      findsOneWidget,
    );
    // Valores por defecto: radio activada, descargas con datos permitidas.
    expect(switchTile(tester, 'Radio automática').value, isTrue);
    expect(switchTile(tester, 'Descargar solo con wifi').value, isFalse);

    await tester.tap(find.text('Descargar solo con wifi'));
    await settle(tester);
    await tester.tap(find.text('Radio automática'));
    await settle(tester);

    final stored = await tester.runAsync(
      () async => (
        wifi: await settings.getBool(
          SettingsKeys.downloadOnlyWifi,
          fallback: false,
        ),
        radio: await settings.getBool(
          SettingsKeys.radioEnabled,
          fallback: true,
        ),
      ),
    );
    expect(stored!.wifi, isTrue);
    expect(stored.radio, isFalse);
    expect(switchTile(tester, 'Descargar solo con wifi').value, isTrue);
    expect(switchTile(tester, 'Radio automática').value, isFalse);
  });

  testWidgets('muestra el espacio ocupado por las descargas', (tester) async {
    await tester.runAsync(() async {
      await addDownloaded('a', 50 * 1024 * 1024);
      await addDownloaded('b', 10 * 1024 * 1024);
    });
    await pumpSettings(tester);

    expect(find.text('Espacio ocupado'), findsOneWidget);
    expect(find.text('60,0 MB · 2 canciones'), findsOneWidget);
  });

  testWidgets('borrar todas las descargas pide confirmación', (tester) async {
    await tester.runAsync(() async {
      await addDownloaded('a', 1024 * 1024);
      await addDownloaded('b', 1024 * 1024);
    });
    await pumpSettings(tester);

    final deleteAll = find.text('Borrar todas las descargas');
    await tester.ensureVisible(deleteAll);
    await tester.tap(deleteAll);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Cancelar no borra nada.
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(await tester.runAsync(songDao.downloaded), hasLength(2));

    await tester.tap(deleteAll);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar todo'));
    // El borrado mezcla BD y disco (async real): repintamos hasta que acabe.
    var remaining = 2;
    for (var i = 0; i < 40 && remaining > 0; i++) {
      await settle(tester);
      remaining = (await tester.runAsync(songDao.downloaded))!.length;
    }

    expect(remaining, 0);
    expect(tmp.listSync(), isEmpty);
    expect(find.text('0 KB · 0 canciones'), findsOneWidget);
  });

  testWidgets('borrar el historial pide confirmación', (tester) async {
    await tester.runAsync(() async {
      final song = await songDao.upsert(SongModel.fromEntity(_song('h')));
      await historyDao.record(song.id);
    });
    await pumpSettings(tester);

    final clear = find.text('Borrar historial de escucha');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await settle(tester);

    expect(await tester.runAsync(historyDao.recent), isEmpty);
  });

  group('downloadPolicy', () {
    test('sin "solo wifi" deja descargar sin mirar la conexión', () async {
      var checked = false;
      final canDownload = downloadPolicy(
        settings,
        connectivity: () async {
          checked = true;
          return [ConnectivityResult.mobile];
        },
      );
      expect(await canDownload(), isTrue);
      expect(checked, isFalse);
    });

    test('con "solo wifi" exige wifi o ethernet', () async {
      await settings.setBool(SettingsKeys.downloadOnlyWifi, true);
      var current = [ConnectivityResult.mobile];
      final canDownload = downloadPolicy(
        settings,
        connectivity: () async => current,
      );
      expect(await canDownload(), isFalse);
      current = [ConnectivityResult.wifi];
      expect(await canDownload(), isTrue);
      current = [ConnectivityResult.ethernet];
      expect(await canDownload(), isTrue);
      current = [ConnectivityResult.none];
      expect(await canDownload(), isFalse);
    });
  });

  testWidgets('muestra la sección Acerca de', (tester) async {
    await pumpSettings(tester);
    final about = find.text('Acerca de');
    await tester.ensureVisible(about);
    expect(about, findsOneWidget);
    expect(find.textContaining('Koda'), findsWidgets);
  });
}
