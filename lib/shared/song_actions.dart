import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_providers.dart';
import '../core/models/song.dart';
import '../features/downloads/presentation/downloads_providers.dart';
import '../features/favorites/presentation/favorites_providers.dart';
import 'export/song_exporter.dart';

final songActionsProvider = Provider<SongActions>(SongActions.new);

/// Acciones sobre canciones que comparten todas las pantallas.
///
/// Antes de reproducir se guarda la canción en la BD: así un resultado de
/// búsqueda que ya está descargado se reproduce desde el archivo local, de
/// forma transparente.
class SongActions {
  SongActions(this._ref);

  final Ref _ref;

  Future<Song> _persist(Song song) async {
    // Volvemos a leerla aunque tenga id: su descarga puede haber cambiado.
    return _ref.read(songDaoProvider).upsert(song);
  }

  /// Alterna "me gusta". Guarda antes la canción (los resultados de búsqueda
  /// llegan con id vacío) y decide con el estado de la BD, no con el de
  /// [song], que puede estar desfasado. También la añade o quita de la
  /// playlist "Me encanta".
  Future<Song> toggleLike(Song song) async {
    final dao = _ref.read(songDaoProvider);
    final saved = await _persist(song);
    await dao.setLiked(saved.id, !saved.isLiked);
    final updated = (await dao.findById(saved.id))!;
    await _ref.read(likedPlaylistProvider).sync(updated);
    return updated;
  }

  Future<void> playQueue(List<Song> songs, int index) async {
    final saved = [for (final s in songs) await _persist(s)];
    await _ref
        .read(audioPlayerServiceProvider)
        .playQueue(saved, startIndex: index);
  }

  Future<void> playShuffled(List<Song> songs) async {
    if (songs.isEmpty) return;
    final audio = _ref.read(audioPlayerServiceProvider);
    await audio.setShuffle(true);
    await playQueue(songs, 0);
  }

  Future<void> playNext(Song song) async =>
      _ref.read(audioPlayerServiceProvider).playNext(await _persist(song));

  Future<void> addToQueue(Song song) async =>
      _ref.read(audioPlayerServiceProvider).addToQueue(await _persist(song));

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

  Future<Song> deleteDownload(Song song) =>
      _ref.read(downloadManagerProvider).delete(song);

  /// Copia el archivo descargado a la carpeta pública de Música. Lanza
  /// [SongExportException] si no se puede.
  Future<String> exportToMusic(Song song) =>
      _ref.read(songExporterProvider).export(song);
}
