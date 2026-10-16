import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../core/domain/entities/song.dart';
import '../core/error/result.dart';
import '../features/downloads/presentation/downloads_providers.dart';
import '../features/favorites/domain/i_liked_playlist_sync.dart';
import '../features/favorites/presentation/favorites_providers.dart';
import '../features/playlists/presentation/playlists_providers.dart';
import 'export/song_exporter.dart';

final songActionsProvider = Provider<SongActions>(SongActions.new);

/// Acciones sobre canciones que comparten todas las pantallas.
///
/// Antes de reproducir se guarda la canción en la BD: así un resultado de
/// búsqueda que ya está descargado se reproduce desde el archivo local, de
/// forma transparente.
///
/// Las acciones que tocan la BD no lanzan por un fallo de los repositorios:
/// lo devuelven como `Err` a quien llama.
class SongActions {
  SongActions(this._ref);

  final Ref _ref;

  Future<Result<Song>> _persist(Song song) {
    // Volvemos a leerla aunque tenga id: su descarga puede haber cambiado.
    // Guardar solo refresca metadatos (conserva descarga y "me gusta"), así
    // que no hay listas que recargar.
    return _ref.read(songRepositoryProvider).save(song);
  }

  /// Alterna "me gusta" con `ToggleLikeUseCase` (guarda la canción, cambia
  /// el "me gusta" y sincroniza "Me encanta"). Si el "me gusta" cambió
  /// (`Ok`, o `Err(LikedPlaylistSyncFailure)` cuando solo falló "Me
  /// encanta", F5) recarga las favoritas y las playlists; el `Err` se
  /// devuelve igual para que la UI avise.
  Future<Result<Song>> toggleLike(Song song) async {
    final result = await _ref.read(toggleLikeUseCaseProvider)(song);
    final likeChanged = switch (result) {
      Ok() => true,
      Err(failure: LikedPlaylistSyncFailure()) => true,
      Err() => false,
    };
    if (likeChanged) {
      // "Me encanta" es una playlist normal: su lista y su detalle se
      // recargan. No se sabe su id aquí, así que se invalida toda la familia
      // de detalles (solo se reconstruyen los que estén abiertos).
      _ref
        ..invalidate(likedSongsProvider)
        ..invalidate(playlistsProvider)
        ..invalidate(playlistProvider);
    }
    return result;
  }

  Future<Result<Unit>> playQueue(List<Song> songs, int index) async {
    final saved = <Song>[];
    for (final s in songs) {
      switch (await _persist(s)) {
        case Ok(:final value):
          saved.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    await _ref
        .read(audioPlayerServiceProvider)
        .playQueue(saved, startIndex: index);
    return const Ok(unit);
  }

  Future<Result<Unit>> playShuffled(List<Song> songs) async {
    if (songs.isEmpty) return const Ok(unit);
    final audio = _ref.read(audioPlayerServiceProvider);
    await audio.setShuffle(true);
    return playQueue(songs, 0);
  }

  Future<Result<Unit>> playNext(Song song) async {
    switch (await _persist(song)) {
      case Ok(:final value):
        await _ref.read(audioPlayerServiceProvider).playNext(value);
        return const Ok(unit);
      case Err(:final failure):
        return Err(failure);
    }
  }

  Future<Result<Unit>> addToQueue(Song song) async {
    switch (await _persist(song)) {
      case Ok(:final value):
        await _ref.read(audioPlayerServiceProvider).addToQueue(value);
        return const Ok(unit);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Un fallo al guardar deja la descarga en estado fallido (se ve en su
  /// tarea); un `Err` solo llega si no se pudo ni encolar.
  Future<Result<Song>> download(Song song) =>
      _ref.read(downloadSongUseCaseProvider)(song);

  Future<Result<Unit>> downloadAll(List<Song> songs) =>
      _ref.read(downloadAllUseCaseProvider)(songs);

  Future<Result<Unit>> cancelDownload(Song song) =>
      _ref.read(cancelDownloadUseCaseProvider)(song);

  Future<Result<Song>> deleteDownload(Song song) =>
      _ref.read(downloadedSongsProvider.notifier).delete(song);

  /// Copia el archivo descargado a la carpeta pública de Música. Lanza
  /// [SongExportException] si no se puede.
  Future<String> exportToMusic(Song song) =>
      _ref.read(songExporterProvider).export(song);
}
