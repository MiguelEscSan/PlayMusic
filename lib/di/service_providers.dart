import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_player_service.dart';
import '../features/downloads/domain/i_download_service.dart';
import '../features/export/data/method_channel_song_exporter.dart';
import '../features/export/domain/i_song_exporter.dart';
import '../features/favorites/domain/i_liked_playlist_sync.dart';
import '../features/history/domain/history_events.dart';
import '../features/lyrics/data/lyrics_repository.dart';
import '../features/lyrics/domain/i_lyrics_repository.dart';
import '../features/playlists/data/spotify_embed_playlist_source.dart';
import '../features/playlists/data/spotify_playlist_importer.dart';
import '../features/playlists/data/youtube_playlist_importer.dart';
import '../features/playlists/data/youtube_track_matcher.dart';
import '../features/playlists/domain/i_playlist_cover_service.dart';
import '../features/playlists/domain/i_playlist_importer.dart';
import '../features/playlists/domain/usecases/import_playlist_from_link_use_case.dart';
import '../features/radio/domain/radio_service.dart';
import '../sources/youtube/youtube_innertube.dart';
import '../sources/youtube/youtube_track_search.dart';
import '../sources/youtube/youtube_suggestion_source.dart';
import '../core/domain/sources/i_track_search.dart';
import '../features/search/domain/suggestion_source.dart';
import 'data_providers.dart';

/// Servicio de audio único de la app. Se crea en `bootstrap()`
/// (AudioService.init es asíncrono) y se inyecta en `main()`.
final audioPlayerServiceProvider = Provider<AudioPlayerService>(
  (ref) => throw UnimplementedError(
    'audioPlayerServiceProvider debe sobrescribirse en main()',
  ),
);

/// Gestor de descargas (`DownloadManager`). Se sobrescribe en `main()` con
/// la instancia de `bootstrap()`.
final downloadServiceProvider = Provider<IDownloadService>(
  (ref) =>
      throw UnimplementedError('downloadServiceProvider se define en main()'),
);

/// Portadas de playlists (`PlaylistCoverService`). Se sobrescribe en
/// `main()` con la instancia de `bootstrap()`.
final playlistCoverServiceProvider = Provider<IPlaylistCoverService>(
  (ref) => throw UnimplementedError(
    'playlistCoverServiceProvider se define en main()',
  ),
);

/// Sincroniza los "me gusta" con la playlist "Me encanta" (`LikedPlaylist`).
/// Se sobrescribe en `main()` con la instancia de `bootstrap()`: la misma
/// que prepara la playlist al arrancar, así que hay un único cerrojo.
final likedPlaylistProvider = Provider<ILikedPlaylistSync>(
  (ref) =>
      throw UnimplementedError('likedPlaylistProvider se define en main()'),
);

/// Radio (`RadioService`). Se sobrescribe en `main()` con la instancia de
/// `bootstrap()`, la misma que sigue la cola al acabarse.
final radioServiceProvider = Provider<RadioService>(
  (ref) => throw UnimplementedError('radioServiceProvider se define en main()'),
);

/// Importador de playlists de YouTube. Crear el cliente no toca la red:
/// solo se conecta al importar.
final youtubePlaylistImporterProvider = Provider<IPlaylistImporter>(
  (ref) => YoutubePlaylistImporter.youtube(
    ref.watch(playlistRepositoryProvider),
    YoutubeInnertube(),
  ),
);

/// Importador de playlists públicas de Spotify, sin iniciar sesión: lee la
/// playlist de sus páginas públicas y busca cada canción en YouTube. Crear
/// los clientes no toca la red.
final spotifyPlaylistImporterProvider = Provider<IPlaylistImporter>(
  (ref) => SpotifyPlaylistImporter(
    ref.watch(playlistRepositoryProvider),
    SpotifyEmbedPlaylistSource.create(),
    YoutubeTrackMatcher.youtube(YoutubeInnertube()),
  ),
);

/// Importa una playlist de YouTube o de Spotify según el enlace. Vive junto
/// a los importadores que elige.
final importPlaylistFromLinkUseCaseProvider =
    Provider<ImportPlaylistFromLinkUseCase>(
      (ref) => ImportPlaylistFromLinkUseCase(
        youtube: ref.watch(youtubePlaylistImporterProvider),
        spotify: ref.watch(spotifyPlaylistImporterProvider),
      ),
    );

/// Repositorio único para que la caché en memoria dure toda la sesión.
final lyricsRepositoryProvider = Provider<ILyricsRepository>(
  (ref) => LyricsRepositoryImpl(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ),
  ),
);

final trackSearchProvider = Provider<ITrackSearch>((ref) {
  final search = YoutubeTrackSearch.create();
  ref.onDispose(search.close);
  return search;
});

final suggestionSourceProvider = Provider<SuggestionSource>((ref) {
  final suggestions = YoutubeSuggestionSource.create();
  ref.onDispose(suggestions.close);
  return suggestions;
});

/// Sobrescribible en tests.
final songExporterProvider = Provider<ISongExporter>(
  (ref) => MethodChannelSongExporter(),
);

/// Avisos de cambios en el historial de escucha. Se sobrescribe en `main()`
/// con la instancia de `bootstrap()` (la misma que usa el
/// `HistoryRecorder`); sin override (tests) se crea una propia.
final historyEventsProvider = Provider<HistoryEvents>((ref) {
  final events = HistoryEvents();
  ref.onDispose(events.dispose);
  return events;
});
