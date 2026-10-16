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
  Future<Result<List<Song>>> getDownloaded() async => const Err(_notConfigured);

  @override
  Future<Result<int>> getDownloadedBytes() async => const Err(_notConfigured);

  @override
  Future<Result<List<Song>>> getLiked() async => const Err(_notConfigured);

  @override
  Future<Result<Song>> save(Song song) async => const Err(_notConfigured);
}
