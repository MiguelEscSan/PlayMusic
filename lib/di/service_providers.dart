import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../core/audio/audio_player_service.dart';
import '../features/downloads/data/download_manager.dart';
import '../features/favorites/data/liked_playlist.dart';
import '../features/lyrics/data/lyrics_repository.dart';
import '../features/playlists/data/playlist_cover_service.dart';
import '../features/playlists/data/youtube_playlist_importer.dart';
import '../features/search/data/search_source.dart';
import '../features/search/data/suggestion_source.dart';
import '../features/search/data/youtube_search_source.dart';
import '../features/search/data/youtube_suggestion_source.dart';
import '../shared/export/song_exporter.dart';
import 'data_providers.dart';

/// Servicio de audio único de la app. Se crea en `bootstrap()`
/// (AudioService.init es asíncrono) y se inyecta en `main()`.
final audioPlayerServiceProvider = Provider<AudioPlayerService>(
  (ref) => throw UnimplementedError(
    'audioPlayerServiceProvider debe sobrescribirse en main()',
  ),
);

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final downloadManagerProvider = Provider<DownloadManager>(
  (ref) =>
      throw UnimplementedError('downloadManagerProvider se define en main()'),
);

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final playlistCoverServiceProvider = Provider<PlaylistCoverService>(
  (ref) => throw UnimplementedError(
    'playlistCoverServiceProvider se define en main()',
  ),
);

/// Sincroniza los "me gusta" con la playlist "Me encanta". Se sobrescribe en
/// `main()` con la instancia de `bootstrap()`: la misma que prepara la
/// playlist al arrancar, así que hay un único cerrojo.
final likedPlaylistProvider = Provider<LikedPlaylist>(
  (ref) =>
      throw UnimplementedError('likedPlaylistProvider se define en main()'),
);

/// Importador de playlists de YouTube. El cliente de YouTube se crea al
/// importar por primera vez (construir la pantalla no toca la red) y se
/// cierra al desechar el provider.
final youtubePlaylistImporterProvider = Provider<YoutubePlaylistImporter>((
  ref,
) {
  YoutubeExplode? yt;
  ref.onDispose(() => yt?.close());
  return YoutubePlaylistImporter.youtube(
    ref.watch(playlistRepositoryProvider),
    () => yt ??= YoutubeExplode(),
  );
});

/// Repositorio único para que la caché en memoria dure toda la sesión.
final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ),
  ),
);

final searchSourceProvider = Provider<SearchSource>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return YoutubeSearchSource(yt);
});

final suggestionSourceProvider = Provider<SuggestionSource>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return YoutubeSuggestionSource(yt);
});

/// Sobrescribible en tests.
final songExporterProvider = Provider<SongExporter>(
  (ref) => MethodChannelSongExporter(),
);
