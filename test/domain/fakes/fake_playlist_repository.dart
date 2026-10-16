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

  @override
  Future<Result<Playlist>> create(String name, {String? description}) async =>
      const Err(_notConfigured);

  @override
  Future<Result<Unit>> delete(String id) async => const Err(_notConfigured);

  @override
  Future<Result<Playlist>> findById(String id) async =>
      const Err(_notConfigured);

  @override
  Future<Result<List<Playlist>>> getAll() async => const Err(_notConfigured);

  @override
  Future<Result<Unit>> moveSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async => const Err(_notConfigured);

  @override
  Future<Result<Unit>> rename(
    String id,
    String name, {
    String? description,
  }) async => const Err(_notConfigured);
}
