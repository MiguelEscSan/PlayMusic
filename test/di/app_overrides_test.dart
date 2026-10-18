import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/bootstrap.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/playback_source.dart';
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/data/repositories/settings_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/playlist_dao.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/core/storage/file_paths.dart';
import 'package:sponify/di/app_overrides.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/downloads/data/download_manager.dart';
import 'package:sponify/features/favorites/data/liked_playlist.dart';
import 'package:sponify/features/history/data/history_dao.dart';
import 'package:sponify/features/history/data/history_recorder.dart';
import 'package:sponify/features/history/data/history_repository_impl.dart';
import 'package:sponify/features/history/domain/history_events.dart';
import 'package:sponify/features/playlists/data/playlist_cover_service.dart';
import 'package:sponify/features/search/data/search_history_dao.dart';
import 'package:sponify/features/radio/domain/radio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_radio_source.dart';

class _FakeAudio implements AudioPlayerService {
  @override
  Stream<Song> get songStarted => const Stream.empty();

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

  test('the app reads the same instances bootstrap built', () async {
    final tmp = Directory.systemTemp.createTempSync('sponify_di');
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final songDao = SongDao(db);
    final playlistDao = PlaylistDao(db, songDao);
    final songs = SongRepositoryImpl(songDao);
    final playlists = PlaylistRepositoryImpl(playlistDao);
    final settings = SettingsDao(db);
    final settingsRepository = SettingsRepositoryImpl(settings);
    final audio = _FakeAudio();
    final historyDao = HistoryDao(db);
    final historyRepository = HistoryRepositoryImpl(historyDao);
    final historyEvents = HistoryEvents();
    final paths = FilePaths(tmp);
    final deps = AppDependencies(
      database: db,
      songDao: songDao,
      playlistDao: playlistDao,
      songRepository: songs,
      playlistRepository: playlists,
      likedPlaylist: LikedPlaylist(
        playlists: playlists,
        songs: songs,
        settings: settingsRepository,
      ),
      playlistCovers: PlaylistCoverService(playlists, paths.coversDir),
      audio: audio,
      downloads: DownloadManager(
        dio: Dio(),
        songRepository: songs,
        paths: paths,
        resolver: _NoNetworkResolver(),
      ),
      historyDao: historyDao,
      historyRepository: historyRepository,
      historyEvents: historyEvents,
      historyRecorder: HistoryRecorder(
        audio: audio,
        history: historyRepository,
        events: historyEvents,
      ),
      settings: settings,
      settingsRepository: settingsRepository,
      searchHistory: SearchHistoryDao(db),
      radio: RadioService(
        radioSources: radioFrom((_) async => const []),
        songRepository: songs,
        settings: settingsRepository,
        history: historyRepository,
      ),
    );
    final container = ProviderContainer(overrides: appOverrides(deps));
    addTearDown(() async {
      container.dispose();
      await deps.historyRecorder.dispose();
      await deps.downloads.dispose();
      await historyEvents.dispose();
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    // Un solo LikedPlaylist (un solo cerrojo) para el arranque y la app.
    expect(container.read(likedPlaylistProvider), same(deps.likedPlaylist));
    expect(container.read(songRepositoryProvider), same(deps.songRepository));
    expect(
      container.read(playlistRepositoryProvider),
      same(deps.playlistRepository),
    );
    expect(container.read(audioPlayerServiceProvider), same(deps.audio));
    expect(
      container.read(settingsRepositoryProvider),
      same(deps.settingsRepository),
    );
    expect(
      container.read(historyRepositoryProvider),
      same(deps.historyRepository),
    );
    expect(container.read(historyEventsProvider), same(deps.historyEvents));
    expect(container.read(downloadServiceProvider), same(deps.downloads));
    expect(
      container.read(playlistCoverServiceProvider),
      same(deps.playlistCovers),
    );
    expect(container.read(radioServiceProvider), same(deps.radio));
  });
}
