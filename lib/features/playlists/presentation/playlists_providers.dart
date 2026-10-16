import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeExplode;

import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/playlist.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
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
  final repository = ref.watch(playlistRepositoryProvider);
  // Un Err se lanza como AsyncError; en la fase 3 lo tratarán los notifiers.
  Future<List<Playlist>> load() async =>
      unwrapOrThrow(await repository.getAll());
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
  }
});

/// Una playlist con sus canciones; null si se ha borrado.
final playlistProvider = StreamProvider.family<Playlist?, String>((
  ref,
  id,
) async* {
  final dao = ref.watch(playlistDaoProvider);
  final repository = ref.watch(playlistRepositoryProvider);
  // Un Err distinto de "no existe" se lanza como AsyncError; en la fase 3 lo
  // tratarán los notifiers.
  Future<Playlist?> load() async => switch (await repository.findById(id)) {
    Ok(:final value) => value,
    Err(failure: NotFoundFailure()) => null,
    Err(:final failure) => throw failure,
  };
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
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
    ref.watch(playlistRepositoryProvider),
    () => yt ??= YoutubeExplode(),
  );
});
