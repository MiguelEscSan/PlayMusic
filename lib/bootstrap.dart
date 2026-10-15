import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'core/audio/audio_bootstrap.dart';
import 'core/audio/playback_source_resolver_impl.dart';
import 'core/audio/sponify_audio_handler.dart';
import 'core/audio/stream_url_provider.dart';
import 'core/database/app_database.dart';
import 'core/database/song_dao.dart';
import 'core/settings/settings_dao.dart';
import 'core/storage/file_paths.dart';
import 'features/downloads/data/download_manager.dart';
import 'features/history/data/history_dao.dart';
import 'features/history/data/history_recorder.dart';
import 'features/playlists/data/playlist_cover_service.dart';
import 'features/playlists/data/playlist_dao.dart';
import 'features/settings/data/download_policy.dart';

/// Servicios de vida larga que se crean una vez al arrancar.
class AppDependencies {
  const AppDependencies({
    required this.database,
    required this.songDao,
    required this.playlistDao,
    required this.playlistCovers,
    required this.audio,
    required this.downloads,
    required this.historyDao,
    required this.historyRecorder,
    required this.settings,
  });

  final AppDatabase database;
  final SongDao songDao;
  final PlaylistDao playlistDao;
  final PlaylistCoverService playlistCovers;
  final SponifyAudioHandler audio;
  final DownloadManager downloads;
  final HistoryDao historyDao;
  final HistoryRecorder historyRecorder;
  final SettingsDao settings;
}

Future<AppDependencies> bootstrap() async {
  final database = await AppDatabase.open();
  final songDao = SongDao(database);
  final playlistDao = PlaylistDao(database, songDao);
  final paths = await FilePaths.create();

  // Un único resolver compartido: reproductor y descargas aprovechan la
  // misma caché de URLs de streaming.
  final resolver = DefaultPlaybackSourceResolver(
    providers: [YoutubeStreamUrlProvider(YoutubeExplode())],
    onLocalFileMissing: (song) => songDao.clearDownload(song.id),
  );

  final audio = await initAudio(resolver);
  final settings = SettingsDao(database);

  final downloads = DownloadManager(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
    songDao: songDao,
    paths: paths,
    resolver: resolver,
    onStorageChanged: audio.onSongStorageChanged,
    // Ajuste "Descargar solo con wifi".
    canDownload: downloadPolicy(settings),
  );

  // El historial escucha al reproductor desde el arranque.
  final historyDao = HistoryDao(database);

  return AppDependencies(
    database: database,
    songDao: songDao,
    playlistDao: playlistDao,
    playlistCovers: PlaylistCoverService(playlistDao, paths.coversDir),
    audio: audio,
    downloads: downloads,
    historyDao: historyDao,
    historyRecorder: HistoryRecorder(audio: audio, dao: historyDao),
    settings: settings,
  );
}
