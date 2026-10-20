import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'core/audio/audio_bootstrap.dart';
import 'core/audio/playback_source_resolver_impl.dart';
import 'core/audio/audio_player_service.dart';
import 'core/data/repositories/playlist_repository_impl.dart';
import 'core/data/repositories/settings_repository_impl.dart';
import 'core/data/repositories/song_repository_impl.dart';
import 'core/database/app_database.dart';
import 'core/database/song_dao.dart';
import 'core/domain/sources/source_registry.dart';
import 'core/domain/repositories/i_playlist_repository.dart';
import 'core/domain/repositories/i_settings_repository.dart';
import 'core/domain/repositories/i_song_repository.dart';
import 'core/error/result.dart';
import 'core/settings/settings_dao.dart';
import 'core/storage/file_paths.dart';
import 'features/downloads/data/download_manager.dart';
import 'features/downloads/data/local_file_missing_handler.dart';
import 'features/favorites/data/liked_playlist.dart';
import 'features/history/data/history_dao.dart';
import 'features/history/data/history_recorder.dart';
import 'features/history/data/history_repository_impl.dart';
import 'features/history/domain/history_events.dart';
import 'features/history/domain/i_history_repository.dart';
import 'features/playlists/data/playlist_cover_service.dart';
import 'features/playback/data/last_playback_recorder.dart';
import 'core/database/playlist_dao.dart';
import 'features/radio/domain/radio_service.dart';
import 'features/search/data/search_history_dao.dart';
import 'features/settings/data/download_policy.dart';
import 'sources/youtube/youtube_radio_source.dart';
import 'sources/youtube/youtube_stream_resolver.dart';

/// Servicios de vida larga que se crean una vez al arrancar.
class AppDependencies {
  const AppDependencies({
    required this.database,
    required this.songDao,
    required this.playlistDao,
    required this.songRepository,
    required this.playlistRepository,
    required this.likedPlaylist,
    required this.playlistCovers,
    required this.audio,
    required this.downloads,
    required this.historyDao,
    required this.historyRepository,
    required this.historyEvents,
    required this.historyRecorder,
    required this.settings,
    required this.settingsRepository,
    required this.searchHistory,
    required this.radio,
  });

  final AppDatabase database;
  final SongDao songDao;
  final PlaylistDao playlistDao;
  final ISongRepository songRepository;
  final IPlaylistRepository playlistRepository;

  /// Única instancia: la misma que prepara "Me encanta" al arrancar y la que
  /// usa la app, para que compartan su cerrojo.
  final LikedPlaylist likedPlaylist;
  final PlaylistCoverService playlistCovers;
  final AudioPlayerService audio;
  final DownloadManager downloads;
  final HistoryDao historyDao;
  final IHistoryRepository historyRepository;

  /// Única instancia: la que anuncia el `HistoryRecorder` y escuchan las
  /// listas de Inicio.
  final HistoryEvents historyEvents;
  final HistoryRecorder historyRecorder;
  final SettingsDao settings;
  final ISettingsRepository settingsRepository;
  final SearchHistoryDao searchHistory;

  /// Única instancia: la que sigue la cola al acabarse y la que arranca la
  /// radio al tocar un resultado de búsqueda.
  final RadioService radio;
}

Future<AppDependencies> bootstrap() async {
  final database = await AppDatabase.open();
  final songDao = SongDao(database);
  final playlistDao = PlaylistDao(database, songDao);
  // Los servicios dependen de las interfaces. DAOs y repositorios van a
  // [AppDependencies] y `main()` los inyecta en los providers: una sola
  // instancia de cada uno para el arranque y la app.
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
    streams: SourceRegistry([YoutubeStreamResolver.create()]),
    onLocalFileMissing: onLocalFileMissing.call,
  );

  final audio = await initAudio(resolver);
  final settings = SettingsDao(database);
  final settingsRepository = SettingsRepositoryImpl(settings);

  // El historial escucha al reproductor desde el arranque.
  final historyDao = HistoryDao(database);
  final historyRepository = HistoryRepositoryImpl(historyDao);
  final historyEvents = HistoryEvents();

  // Radio automática: al acabarse la cola sigue con canciones parecidas,
  // ordenadas por los gustos del usuario.
  final radio = RadioService(
    radioSources: SourceRegistry([YoutubeRadioSource.create()]),
    songRepository: songRepository,
    settings: settingsRepository,
    history: historyRepository,
  );
  audio.onQueueEnded = radio.nextFor;

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
    canDownload: downloadPolicy(settingsRepository),
  );
  onLocalFileMissing.manager = downloads;

  // Los "me gusta" de antes de existir "Me encanta" pasan a la playlist.
  // Si falla no se bloquea el arranque: la playlist a medias se descarta y
  // se vuelve a crear y rellenar en el siguiente arranque o "me gusta".
  final likedPlaylist = LikedPlaylist(
    playlists: playlistRepository,
    songs: songRepository,
    settings: settingsRepository,
  );
  final liked = await songRepository.getLiked();
  if (liked case Ok(value: final songs) when songs.isNotEmpty) {
    final ensured = await likedPlaylist.ensure();
    if (ensured case Err(:final failure)) {
      debugPrint('No se pudo preparar "Me encanta": $failure');
    }
  } else if (liked case Err(:final failure)) {
    debugPrint('No se pudieron leer los "me gusta": $failure');
  }

  // Guarda la reproducción mientras suena y la retoma (en pausa) al abrir.
  LastPlaybackRecorder(audio: audio, settings: settingsRepository);
  unawaited(
    restoreLastPlayback(
      settings: settingsRepository,
      songs: songRepository,
      restore: audio.restoreQueue,
    ),
  );

  return AppDependencies(
    database: database,
    songDao: songDao,
    playlistDao: playlistDao,
    songRepository: songRepository,
    playlistRepository: playlistRepository,
    likedPlaylist: likedPlaylist,
    playlistCovers: PlaylistCoverService(playlistRepository, paths.coversDir),
    audio: audio,
    downloads: downloads,
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
    searchHistory: SearchHistoryDao(database),
    radio: radio,
  );
}
