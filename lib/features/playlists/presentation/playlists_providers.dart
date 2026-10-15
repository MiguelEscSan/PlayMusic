import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeExplode;

import '../../../core/models/playlist.dart';
import '../data/playlist_cover_service.dart';
import '../data/playlist_dao.dart';
import '../data/youtube_playlist_importer.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final playlistDaoProvider = Provider<PlaylistDao>(
  (ref) => throw UnimplementedError('playlistDaoProvider se define en main()'),
);

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final playlistCoverServiceProvider = Provider<PlaylistCoverService>(
  (ref) => throw UnimplementedError(
    'playlistCoverServiceProvider se define en main()',
  ),
);

final playlistsProvider = StreamProvider<List<Playlist>>((ref) async* {
  final dao = ref.watch(playlistDaoProvider);
  yield await dao.all();
  await for (final _ in dao.changes) {
    yield await dao.all();
  }
});

/// Una playlist con sus canciones; null si se ha borrado.
final playlistProvider = StreamProvider.family<Playlist?, String>((
  ref,
  id,
) async* {
  final dao = ref.watch(playlistDaoProvider);
  yield await dao.findById(id);
  await for (final _ in dao.changes) {
    yield await dao.findById(id);
  }
});

/// Importador de playlists de YouTube. El cliente de YouTube se crea al
/// importar por primera vez (construir la pantalla no toca la red) y se
/// cierra al desechar el provider.
final youtubePlaylistImporterProvider = Provider<YoutubePlaylistImporter>((
  ref,
) {
  YoutubeExplode? yt;
  ref.onDispose(() => yt?.close());
  return YoutubePlaylistImporter.youtube(
    ref.watch(playlistDaoProvider),
    () => yt ??= YoutubeExplode(),
  );
});
