import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'core/audio/audio_bootstrap.dart';
import 'core/audio/playback_source_resolver_impl.dart';
import 'core/audio/sponify_audio_handler.dart';
import 'core/audio/stream_url_provider.dart';
import 'core/data/repositories/playlist_repository_impl.dart';
import 'core/data/repositories/song_repository_impl.dart';
import 'core/database/app_database.dart';
import 'core/database/song_dao.dart';
import 'core/error/result.dart';
import 'core/settings/settings_dao.dart';
import 'core/storage/file_paths.dart';
import 'features/downloads/data/download_manager.dart';
import 'features/downloads/data/local_file_missing_handler.dart';
import 'features/favorites/data/liked_playlist.dart';
import 'features/history/data/history_dao.dart';
import 'features/history/data/history_recorder.dart';
import 'features/playlists/data/playlist_cover_service.dart';
import 'features/playlists/data/playlist_dao.dart';
import 'features/radio/radio_service.dart';
import 'features/search/data/search_history_dao.dart';
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
    required this.searchHistory,
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
  final SearchHistoryDao searchHistory;
}

Future<AppDependencies> bootstrap() async {
  final database = await AppDatabase.open();
  final songDao = SongDao(database);
  final playlistDao = PlaylistDao(database, songDao);
  // Los servicios dependen de las interfaces; los DAOs siguen en
  // [AppDependencies] porque los providers de los repositorios se derivan
  // de ellos.
  final songRepository = SongRepositoryImpl(songDao);
  final playlistRepository = PlaylistRepositoryImpl(playlistDao);
  final paths = await FilePaths.create();

  // El resolver y las descargas se necesitan mutuamente: el resolver avisa
  // de un archivo perdido y el DownloadManager lo olvida (y avisa a la vista
  // Descargas para que deje de mostrarlo). El audio ya resuelve canciones al
  // arrancar, antes de que exista el DownloadManager: hasta entonces el
  // handler limpia la BD directamente.
  final onLocalFileMissing = LocalFileMissingHandler(songRepository);

  // Un único resolver compartido: reproductor y descargas aprovechan la
  // misma caché de URLs de streaming.
  final resolver = DefaultPlaybackSourceResolver(
    providers: [YoutubeStreamUrlProvider(YoutubeExplode())],
    onLocalFileMissing: onLocalFileMissing.call,
  );

  final audio = await initAudio(resolver);
  final settings = SettingsDao(database);

  // Radio automática: al acabarse la cola sigue con canciones relacionadas.
  audio.onQueueEnded = RadioService.youtube(
    YoutubeExplode(),
    songRepository: songRepository,
    settings: settings,
  ).nextFor;

  final downloads = DownloadManager(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
    songRepository: songRepository,
    paths: paths,
    resolver: resolver,
    onStorageChanged: audio.onSongStorageChanged,
    // Ajuste "Descargar solo con wifi".
    canDownload: downloadPolicy(settings),
  );
  onLocalFileMissing.manager = downloads;

  // Los "me gusta" de antes de existir "Me encanta" pasan a la playlist.
  // Si falla no se bloquea el arranque: la playlist a medias se descarta y
  // se vuelve a crear y rellenar en el siguiente arranque o "me gusta".
  final liked = await songRepository.getLiked();
  if (liked case Ok(value: final songs) when songs.isNotEmpty) {
    final ensured = await LikedPlaylist(
      playlists: playlistRepository,
      songs: songRepository,
      settings: settings,
    ).ensure();
    if (ensured case Err(:final failure)) {
      debugPrint('No se pudo preparar "Me encanta": $failure');
    }
  } else if (liked case Err(:final failure)) {
    debugPrint('No se pudieron leer los "me gusta": $failure');
  }

  // El historial escucha al reproductor desde el arranque.
  final historyDao = HistoryDao(database);

  return AppDependencies(
    database: database,
    songDao: songDao,
    playlistDao: playlistDao,
    playlistCovers: PlaylistCoverService(playlistRepository, paths.coversDir),
    audio: audio,
    downloads: downloads,
    historyDao: historyDao,
    historyRecorder: HistoryRecorder(audio: audio, dao: historyDao),
    settings: settings,
    searchHistory: SearchHistoryDao(database),
  );
}
