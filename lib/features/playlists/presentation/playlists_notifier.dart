import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';
import '../../../core/domain/entities/playlist.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../domain/i_playlist_importer.dart';
import 'playlists_providers.dart';

/// Todas las playlists, la modificada más recientemente primero.
final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      PlaylistsNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño de la lista de playlists y de las operaciones sobre una playlist
/// completa (crear, renombrar, borrar, portada, importar, añadir desde la
/// hoja). Cada mutación pasa por su caso de uso, devuelve su `Result` y, si
/// sale bien, recarga la lista y el detalle afectado.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final getPlaylists = ref.watch(getPlaylistsUseCaseProvider);
    rebuildOnDownloadsChange(ref);
    return switch (await getPlaylists()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  Future<Result<Playlist>> create(String name) async {
    final result = await ref.read(createPlaylistUseCaseProvider)(name);
    if (result.isOk) _refresh();
    return result;
  }

  Future<Result<Unit>> rename(String id, String name) =>
      _mutate(id, () => ref.read(renamePlaylistUseCaseProvider)(id, name));

  /// Borra la playlist y su portada personalizada.
  Future<Result<Unit>> delete(String id) =>
      _mutate(id, () => ref.read(deletePlaylistUseCaseProvider)(id));

  Future<Result<Unit>> setCoverFromFile(String id, String imagePath) => _mutate(
    id,
    () => ref.read(setPlaylistCoverFromFileUseCaseProvider)(id, imagePath),
  );

  /// Vuelve a la portada automática.
  Future<Result<Unit>> clearCover(String id) =>
      _mutate(id, () => ref.read(clearPlaylistCoverUseCaseProvider)(id));

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

  /// Importa una playlist de YouTube. Nunca lanza: enlace no válido,
  /// playlist vacía, red o un fallo al guardar llegan como `Err` tipado
  /// (ver `ImportYoutubePlaylistUseCase`).
  Future<Result<ImportResult>> importFromYoutube(
    String link, {
    ImportProgress? onProgress,
  }) async {
    final result = await ref.read(importYoutubePlaylistUseCaseProvider)(
      link,
      onProgress: onProgress,
    );
    // Aunque falle a medias, la playlist puede haberse creado.
    _refresh();
    return result;
  }

  /// Importa una playlist de YouTube o de Spotify, eligiendo el importador
  /// por el enlace. Nunca lanza: como [importFromYoutube] (ver
  /// `ImportPlaylistFromLinkUseCase`).
  Future<Result<ImportResult>> importFromLink(
    String link, {
    ImportProgress? onProgress,
  }) async {
    final result = await ref.read(importPlaylistFromLinkUseCaseProvider)(
      link,
      onProgress: onProgress,
    );
    // Aunque falle a medias, la playlist puede haberse creado.
    _refresh();
    return result;
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
