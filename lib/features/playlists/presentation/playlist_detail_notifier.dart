import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repository_providers.dart';
import '../../../core/domain/entities/playlist.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/repositories/i_playlist_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import 'playlists_providers.dart';

/// Una playlist con sus canciones. Si no existe es un
/// `AsyncError(NotFoundFailure)`.
final playlistProvider = AsyncNotifierProvider.autoDispose
    .family<PlaylistDetailNotifier, Playlist, String>(
      PlaylistDetailNotifier.new,
      retry: noAutomaticRetry,
    );

/// Dueño del estado de una playlist abierta y de los cambios en sus
/// canciones.
///
/// Quitar, deshacer y mover se aplican al instante al [state] (la lista
/// responde sin esperar a la BD) y después se guardan. Si el repositorio
/// devuelve `Err`, el [state] vuelve a lo que había y el `Err` se devuelve
/// para que la UI avise. Si sale bien, se recarga [playlistsProvider]
/// (cambian contador, duración y portada).
class PlaylistDetailNotifier extends AsyncNotifier<Playlist> {
  PlaylistDetailNotifier(this.id);

  final String id;

  @override
  Future<Playlist> build() async {
    final repository = ref.watch(playlistRepositoryProvider);
    rebuildOnDownloadsChange(ref);
    return switch (await repository.findById(id)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  IPlaylistRepository get _repository => ref.read(playlistRepositoryProvider);

  /// Quita la canción que ocupa la posición [index].
  Future<Result<Unit>> removeSongAt(int index) => _optimistic(
    (songs) => songs..removeAt(index),
    () => _repository.removeSongAt(id, index),
  );

  /// Añade [song] en la posición [at] (por defecto, al final). Sirve para
  /// deshacer un quitar: la BD la añade al final y luego se recoloca.
  /// `Ok(false)` si ya estaba en la playlist.
  Future<Result<bool>> addSong(Song song, {int? at}) async {
    final last = state.value?.length ?? 0;
    final position = at == null || at > last ? last : at;
    Result<bool>? added;
    final result = await _optimistic(
      (songs) => songs..insert(position, song),
      () async {
        final r = await ref.read(addSongToPlaylistUseCaseProvider)(id, song);
        added = r;
        return switch (r) {
          Ok(value: true) when position != last => _repository.moveSong(
            id,
            last,
            position,
          ),
          Ok() => const Ok(unit),
          Err(:final failure) => Err(failure),
        };
      },
    );
    // Ya estaba, o se añadió pero no se pudo recolocar: el estado optimista
    // no coincide con la BD, así que se vuelve a leer.
    final inSync = switch ((added, result)) {
      (Ok(value: false), _) => false,
      (Ok(value: true), Err()) => false,
      _ => true,
    };
    if (!inSync && ref.mounted) ref.invalidateSelf();
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok() => added!,
    };
  }

  /// Mueve la canción de [oldIndex] a [newIndex] (posición final ya
  /// corregida, como en el repositorio).
  Future<Result<Unit>> move(int oldIndex, int newIndex) => _optimistic(
    (songs) => songs..insert(newIndex, songs.removeAt(oldIndex)),
    () => _repository.moveSong(id, oldIndex, newIndex),
  );

  Future<Result<Unit>> rename(String name) =>
      ref.read(playlistsProvider.notifier).rename(id, name);

  /// Aplica [edit] a una copia de las canciones, guarda con [persist] y, si
  /// falla, restaura el estado anterior.
  Future<Result<Unit>> _optimistic(
    List<Song> Function(List<Song> songs) edit,
    Future<Result<Unit>> Function() persist,
  ) async {
    final previous = state.value;
    if (previous == null) {
      return const Err(UnexpectedFailure('La playlist aún no se ha cargado'));
    }
    // Mantiene vivo el detalle aunque se cierre la pantalla a mitad.
    final keepAlive = ref.keepAlive();
    try {
      state = AsyncData(previous.copyWith(songs: edit([...previous.songs])));
      final result = await persist();
      if (!ref.mounted) return result;
      switch (result) {
        case Ok():
          ref.invalidate(playlistsProvider);
        case Err():
          state = AsyncData(previous);
      }
      return result;
    } finally {
      keepAlive.close();
    }
  }
}
