import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_providers.dart';
import '../core/di/repository_providers.dart';
import '../core/domain/entities/song.dart';
import '../core/error/result.dart';
import '../features/downloads/presentation/downloads_providers.dart';
import '../features/favorites/presentation/favorites_providers.dart';
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
    return _ref.read(songRepositoryProvider).save(song);
  }

  /// Alterna "me gusta". Guarda antes la canción (los resultados de búsqueda
  /// llegan con id vacío) y decide con el estado de la BD, no con el de
  /// [song], que puede estar desfasado. También la añade o quita de la
  /// playlist "Me encanta".
  Future<Result<Song>> toggleLike(Song song) async {
    final Song saved;
    switch (await _persist(song)) {
      case Ok(:final value):
        saved = value;
      case Err(:final failure):
        return Err(failure);
    }
    final Song updated;
    switch (await _ref.read(toggleFavoriteUseCaseProvider)(saved)) {
      case Ok(:final value):
        updated = value;
      case Err(:final failure):
        return Err(failure);
    }
    final synced = await _ref.read(likedPlaylistProvider).sync(updated);
    return synced.map((_) => updated);
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

  /// Un fallo al guardar deja la descarga en estado fallido (ver
  /// `DownloadManager.download`).
  Future<Song> download(Song song) =>
      _ref.read(downloadManagerProvider).download(song);

  Future<void> downloadAll(List<Song> songs) async {
    final manager = _ref.read(downloadManagerProvider);
    for (final s in songs.where((s) => !s.isDownloaded)) {
      await manager.download(s);
    }
  }

  Future<void> cancelDownload(Song song) =>
      _ref.read(downloadManagerProvider).cancel(song);

  Future<Result<Song>> deleteDownload(Song song) =>
      _ref.read(downloadManagerProvider).delete(song);

  /// Copia el archivo descargado a la carpeta pública de Música. Lanza
  /// [SongExportException] si no se puede.
  Future<String> exportToMusic(Song song) =>
      _ref.read(songExporterProvider).export(song);
}
