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
/// devuelve `Err`, el `Err` se devuelve para que la UI avise y el [state] se
/// vuelve a leer de la BD. Si sale bien, se recarga [playlistsProvider]
/// (cambian contador, duración y portada).
///
/// No se restaura una copia del estado anterior: con varias escrituras a la
/// vez, esa copia resucitaría filas que otra escritura ya quitó de la BD
/// (F6). Tampoco se relee la BD mientras queden escrituras pendientes: la
/// lectura no las vería. Por eso, si alguna escritura falla o el detalle se
/// recarga con escrituras en vuelo (p. ej. al cambiar las descargas, F7),
/// el estado queda "desfasado" y se relee cuando termina la última.
class PlaylistDetailNotifier extends AsyncNotifier<Playlist> {
  PlaylistDetailNotifier(this.id);

  final String id;

  /// Escrituras optimistas aún sin respuesta del repositorio.
  int _pending = 0;

  /// El [state] puede no coincidir con la BD: se relee cuando [_pending]
  /// llegue a cero.
  bool _stale = false;

  @override
  Future<Playlist> build() async {
    // Esta lectura puede llegar antes que las escrituras en vuelo.
    if (_pending > 0) _stale = true;
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
    // Ya estaba: el estado optimista la tiene dos veces, así que se vuelve a
    // leer. (Si se añadió pero no se pudo recolocar, el `Err` ya relee.)
    if (added case Ok(value: false) when ref.mounted) {
      _stale = true;
      await _resyncIfStale();
    }
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

  /// Aplica [edit] a una copia de las canciones y guarda con [persist]. Si
  /// falla, o si el estado quedó desfasado mientras tanto, lo relee de la BD
  /// cuando ya no quedan escrituras pendientes.
  Future<Result<Unit>> _optimistic(
    List<Song> Function(List<Song> songs) edit,
    Future<Result<Unit>> Function() persist,
  ) async {
    final current = state.value;
    if (current == null) {
      return const Err(UnexpectedFailure('La playlist aún no se ha cargado'));
    }
    // Una recarga en curso puede leer la BD antes de esta escritura.
    if (state.isLoading) _stale = true;
    // Mantiene vivo el detalle aunque se cierre la pantalla a mitad.
    final keepAlive = ref.keepAlive();
    _pending++;
    try {
      state = AsyncData(current.copyWith(songs: edit([...current.songs])));
      final result = await persist();
      if (result.isErr) _stale = true;
      if (ref.mounted && result.isOk) ref.invalidate(playlistsProvider);
      return result;
    } finally {
      _pending--;
      if (ref.mounted) await _resyncIfStale();
      keepAlive.close();
    }
  }

  /// Relee la playlist de la BD si el estado está desfasado y no quedan
  /// escrituras pendientes. Un fallo al releer queda en el [state] como
  /// `AsyncError` (la pantalla lo muestra con su botón de reintentar).
  Future<void> _resyncIfStale() async {
    if (_pending > 0 || !_stale) return;
    _stale = false;
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // Ya está en el state.
    }
  }
}
