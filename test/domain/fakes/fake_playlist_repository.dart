import 'dart:async';

import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_playlist_repository.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';

/// Fake escrito a mano: registra las llamadas a [addSong]/[removeSong] y
/// devuelve resultados configurables. El resto de métodos devuelve un `Err`.
class FakePlaylistRepository implements IPlaylistRepository {
  Result<bool> addSongResult = const Ok(true);
  Result<bool> removeSongResult = const Ok(true);

  final List<({String playlistId, Song song})> addSongCalls = [];
  final List<({String playlistId, String songId})> removeSongCalls = [];

  static const _notConfigured = UnexpectedFailure('not configured in fake');

  @override
  Future<Result<bool>> addSong(String playlistId, Song song) async {
    addSongCalls.add((playlistId: playlistId, song: song));
    return addSongResult;
  }

  @override
  Future<Result<bool>> removeSong(String playlistId, String songId) async {
    removeSongCalls.add((playlistId: playlistId, songId: songId));
    return removeSongResult;
  }

  // Resultados configurables del resto de métodos (por defecto, `Err`).
  Result<Playlist> createResult = const Err(_notConfigured);
  Result<Playlist> findByIdResult = const Err(_notConfigured);
  Result<List<Playlist>> getAllResult = const Err(_notConfigured);
  Result<Unit> removeSongAtResult = const Err(_notConfigured);
  Result<Unit> moveSongResult = const Err(_notConfigured);
  Result<Unit> renameResult = const Err(_notConfigured);

  final List<String> createCalls = [];
  final List<String> findByIdCalls = [];
  final List<({String id, String name})> renameCalls = [];
  final List<({String playlistId, int index})> removeSongAtCalls = [];
  final List<({String playlistId, int oldIndex, int newIndex})> moveSongCalls =
      [];

  @override
  Future<Result<Playlist>> create(String name, {String? description}) async {
    createCalls.add(name);
    return createResult;
  }

  @override
  Future<Result<Unit>> delete(String id) async => const Err(_notConfigured);

  @override
  Future<Result<Playlist>> findById(String id) async {
    findByIdCalls.add(id);
    return findByIdResult;
  }

  @override
  Future<Result<List<Playlist>>> getAll() async => getAllResult;

  @override
  Future<Result<Unit>> removeSongAt(String playlistId, int index) async {
    removeSongAtCalls.add((playlistId: playlistId, index: index));
    return removeSongAtResult;
  }

  @override
  Future<Result<Unit>> setCover(String id, String? coverUrl) async =>
      const Err(_notConfigured);

  @override
  Future<Result<Unit>> moveSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    moveSongCalls.add((
      playlistId: playlistId,
      oldIndex: oldIndex,
      newIndex: newIndex,
    ));
    return moveSongResult;
  }

  @override
  Future<Result<Unit>> rename(
    String id,
    String name, {
    String? description,
  }) async {
    renameCalls.add((id: id, name: name));
    return renameResult;
  }
}

/// Delega en un repositorio real, pero cada operación con contador
/// (`...Failures`) devuelve un `Err` las próximas N veces.
class FlakyPlaylistRepository implements IPlaylistRepository {
  FlakyPlaylistRepository(this._inner);

  final IPlaylistRepository _inner;
  int setCoverFailures = 0;
  int addSongFailures = 0;
  int removeSongAtFailures = 0;
  int moveSongFailures = 0;
  int renameFailures = 0;
  int getAllFailures = 0;
  int findByIdFailures = 0;

  static const failure = UnexpectedFailure('flaky repository');

  @override
  Future<Result<Unit>> setCover(String id, String? coverUrl) async {
    if (setCoverFailures > 0) {
      setCoverFailures--;
      return const Err(failure);
    }
    return _inner.setCover(id, coverUrl);
  }

  @override
  Future<Result<bool>> addSong(String playlistId, Song song) async {
    if (addSongFailures > 0) {
      addSongFailures--;
      return const Err(failure);
    }
    return _inner.addSong(playlistId, song);
  }

  @override
  Future<Result<bool>> removeSong(String playlistId, String songId) =>
      _inner.removeSong(playlistId, songId);

  @override
  Future<Result<Playlist>> create(String name, {String? description}) =>
      _inner.create(name, description: description);

  @override
  Future<Result<Unit>> delete(String id) => _inner.delete(id);

  @override
  Future<Result<Playlist>> findById(String id) async {
    if (findByIdFailures > 0) {
      findByIdFailures--;
      return const Err(failure);
    }
    return _inner.findById(id);
  }

  @override
  Future<Result<List<Playlist>>> getAll() async {
    if (getAllFailures > 0) {
      getAllFailures--;
      return const Err(failure);
    }
    return _inner.getAll();
  }

  /// Si no es null, la próxima llamada a [removeSongAt] decide al instante
  /// si falla, pero no toca la BD ni responde hasta que se complete.
  Completer<void>? removeSongAtGate;

  @override
  Future<Result<Unit>> removeSongAt(String playlistId, int index) async {
    final fail = removeSongAtFailures > 0;
    if (fail) removeSongAtFailures--;
    final gate = removeSongAtGate;
    removeSongAtGate = null;
    if (gate != null) await gate.future;
    if (fail) return const Err(failure);
    return _inner.removeSongAt(playlistId, index);
  }

  @override
  Future<Result<Unit>> moveSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    if (moveSongFailures > 0) {
      moveSongFailures--;
      return const Err(failure);
    }
    return _inner.moveSong(playlistId, oldIndex, newIndex);
  }

  @override
  Future<Result<Unit>> rename(
    String id,
    String name, {
    String? description,
  }) async {
    if (renameFailures > 0) {
      renameFailures--;
      return const Err(failure);
    }
    return _inner.rename(id, name, description: description);
  }
}
