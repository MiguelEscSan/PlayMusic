import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/domain/repositories/i_song_repository.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';

/// Fake escrito a mano: registra las llamadas a [setLiked] y devuelve un
/// resultado configurable. El resto de métodos devuelve un `Err`.
class FakeSongRepository implements ISongRepository {
  Result<Unit> setLikedResult = const Ok(unit);

  final List<({String songId, bool liked})> setLikedCalls = [];

  static const _notConfigured = UnexpectedFailure('not configured in fake');

  @override
  Future<Result<Unit>> setLiked(String songId, {required bool liked}) async {
    setLikedCalls.add((songId: songId, liked: liked));
    return setLikedResult;
  }

  @override
  Future<Result<Unit>> clearDownload(String songId) async =>
      const Err(_notConfigured);

  @override
  Future<Result<Song>> findById(String id) async => const Err(_notConfigured);

  @override
  Future<Result<Song>> findBySource(SongSource source, String sourceId) async =>
      const Err(_notConfigured);

  @override
  Future<Result<Song>> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
  }) async => const Err(_notConfigured);

  // Resultados configurables (por defecto, `Err`). [saveResult] null
  // devuelve la canción recibida tal cual.
  Result<List<Song>> getDownloadedResult = const Err(_notConfigured);
  Result<List<Song>> getLikedResult = const Err(_notConfigured);
  Result<Song>? saveResult = const Err(_notConfigured);

  final List<Song> saveCalls = [];

  @override
  Future<Result<List<Song>>> getDownloaded() async => getDownloadedResult;

  @override
  Future<Result<int>> getDownloadedBytes() async => const Err(_notConfigured);

  @override
  Future<Result<List<Song>>> getLiked() async => getLikedResult;

  @override
  Future<Result<Song>> save(Song song) async {
    saveCalls.add(song);
    return saveResult ?? Ok(song);
  }
}

/// Delega en un repositorio real, pero cada operación con contador
/// (`...Failures`) devuelve un `Err` las próximas N veces. Cuenta las
/// lecturas de las listas para comprobar cuándo se recargan.
class FlakySongRepository implements ISongRepository {
  FlakySongRepository(this._inner);

  final ISongRepository _inner;
  int getDownloadedFailures = 0;
  int getLikedFailures = 0;
  int setLikedFailures = 0;
  int clearDownloadFailures = 0;
  int getDownloadedCalls = 0;
  int getLikedCalls = 0;

  static const failure = UnexpectedFailure('flaky song repository');

  @override
  Future<Result<List<Song>>> getDownloaded() async {
    getDownloadedCalls++;
    if (getDownloadedFailures > 0) {
      getDownloadedFailures--;
      return const Err(failure);
    }
    return _inner.getDownloaded();
  }

  @override
  Future<Result<List<Song>>> getLiked() async {
    getLikedCalls++;
    if (getLikedFailures > 0) {
      getLikedFailures--;
      return const Err(failure);
    }
    return _inner.getLiked();
  }

  @override
  Future<Result<Unit>> setLiked(String songId, {required bool liked}) async {
    if (setLikedFailures > 0) {
      setLikedFailures--;
      return const Err(failure);
    }
    return _inner.setLiked(songId, liked: liked);
  }

  @override
  Future<Result<Unit>> clearDownload(String songId) async {
    if (clearDownloadFailures > 0) {
      clearDownloadFailures--;
      return const Err(failure);
    }
    return _inner.clearDownload(songId);
  }

  @override
  Future<Result<Song>> save(Song song) => _inner.save(song);

  @override
  Future<Result<Song>> findById(String id) => _inner.findById(id);

  @override
  Future<Result<Song>> findBySource(SongSource source, String sourceId) =>
      _inner.findBySource(source, sourceId);

  @override
  Future<Result<int>> getDownloadedBytes() => _inner.getDownloadedBytes();

  @override
  Future<Result<Song>> markDownloaded(
    String id, {
    required String localPath,
    required int sizeBytes,
  }) => _inner.markDownloaded(id, localPath: localPath, sizeBytes: sizeBytes);
}
