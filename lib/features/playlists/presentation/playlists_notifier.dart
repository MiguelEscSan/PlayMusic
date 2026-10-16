import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/playlist.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/result.dart';
import '../data/youtube_playlist_importer.dart';
import 'playlists_providers.dart';

/// Todas las playlists, la modificada más recientemente primero.
final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      PlaylistsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de playlists y de las operaciones sobre una playlist
/// completa (crear, renombrar, borrar, portada, importar, añadir desde la
/// hoja). Cada mutación devuelve el `Result` del repositorio y, si sale bien,
/// recarga la lista y el detalle afectado.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final repository = ref.watch(playlistRepositoryProvider);
    rebuildOnDownloadsChange(ref);
    return switch (await repository.getAll()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  IPlaylistRepository get _repository => ref.read(playlistRepositoryProvider);

  Future<Result<Playlist>> create(String name) async {
    final result = await _repository.create(name);
    if (result.isOk) _refresh();
    return result;
  }

  Future<Result<Unit>> rename(String id, String name) =>
      _mutate(id, () => _repository.rename(id, name));

  /// Borra la playlist y su portada personalizada.
  Future<Result<Unit>> delete(String id) => _mutate(
    id,
    () => ref.read(playlistCoverServiceProvider).deletePlaylist(id),
  );

  Future<Result<Unit>> setCoverFromFile(String id, String imagePath) => _mutate(
    id,
    () => ref.read(playlistCoverServiceProvider).setFromFile(id, imagePath),
  );

  /// Vuelve a la portada automática.
  Future<Result<Unit>> clearCover(String id) =>
      _mutate(id, () => ref.read(playlistCoverServiceProvider).clear(id));

  /// Añade [song] al final de la playlist [playlistId]. `Ok(false)` si ya
  /// estaba.
  Future<Result<bool>> addSong(String playlistId, Song song) async {
    final result = await ref.read(addSongToPlaylistUseCaseProvider)(
      playlistId,
      song,
    );
    if (result case Ok(value: true)) _refresh(playlistId);
    return result;
  }

  /// Importa una playlist de YouTube. Lanza las mismas excepciones que
  /// [YoutubePlaylistImporter.importFromUrl] (enlace no válido, playlist
  /// vacía, red); un fallo al guardar llega como `Err`.
  Future<Result<ImportResult>> importFromYoutube(
    String link, {
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      return await ref
          .read(youtubePlaylistImporterProvider)
          .importFromUrl(link, onProgress: onProgress);
    } finally {
      // Aunque falle a medias, la playlist puede haberse creado.
      _refresh();
    }
  }

  Future<Result<Unit>> _mutate(
    String id,
    Future<Result<Unit>> Function() change,
  ) async {
    final result = await change();
    if (result.isOk) _refresh(id);
    return result;
  }

  void _refresh([String? playlistId]) {
    if (!ref.mounted) return;
    ref.invalidateSelf();
    if (playlistId != null) ref.invalidate(playlistProvider(playlistId));
  }
}
