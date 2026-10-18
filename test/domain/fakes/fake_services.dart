import 'dart:async';

import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/domain/download_task.dart';
import 'package:sponify/features/downloads/domain/i_download_service.dart';
import 'package:sponify/features/favorites/domain/i_liked_playlist_sync.dart';
import 'package:sponify/features/playlists/domain/i_playlist_cover_service.dart';
import 'package:sponify/features/playlists/domain/i_playlist_importer.dart';
import 'package:sponify/features/playlists/domain/i_spotify_playlist_source.dart';
import 'package:sponify/features/playlists/domain/i_track_matcher.dart';
import 'package:sponify/features/playlists/domain/remote_playlist.dart';

/// Servicio de descargas falso: registra las llamadas y devuelve
/// resultados configurables. Si [error] no es null, las acciones lo lanzan.
class FakeDownloadService implements IDownloadService {
  final tasks = StreamController<Map<String, DownloadTask>>.broadcast();
  final changes = StreamController<Song>.broadcast();

  Object? error;
  Result<Song>? deleteResult;
  Result<Unit> deleteAllResult = const Ok(unit);

  final List<Song> downloadCalls = [];
  final List<Song> cancelCalls = [];
  final List<Song> deleteCalls = [];
  int deleteAllCalls = 0;

  void _maybeThrow() {
    if (error case final e?) throw e;
  }

  @override
  Stream<Map<String, DownloadTask>> get tasksStream => tasks.stream;

  @override
  Stream<Song> get downloadsChanged => changes.stream;

  @override
  Future<Song> download(Song song) async {
    downloadCalls.add(song);
    _maybeThrow();
    return song.copyWith(id: 'saved-${song.sourceId}');
  }

  @override
  Future<void> cancel(Song song) async {
    cancelCalls.add(song);
    _maybeThrow();
  }

  @override
  Future<Result<Song>> delete(Song song) async {
    deleteCalls.add(song);
    _maybeThrow();
    return deleteResult ?? Ok(song.copyWith(clearLocalFile: true));
  }

  @override
  Future<Result<Unit>> deleteAll() async {
    deleteAllCalls++;
    _maybeThrow();
    return deleteAllResult;
  }
}

/// Portadas falsas: cada acción devuelve [result] y se registra en [calls].
class FakePlaylistCoverService implements IPlaylistCoverService {
  Result<Unit> result = const Ok(unit);
  Object? error;
  final List<String> calls = [];

  Future<Result<Unit>> _answer(String call) async {
    calls.add(call);
    if (error case final e?) throw e;
    return result;
  }

  @override
  Future<Result<Unit>> setFromFile(String playlistId, String sourcePath) =>
      _answer('setFromFile($playlistId, $sourcePath)');

  @override
  Future<Result<Unit>> clear(String playlistId) =>
      _answer('clear($playlistId)');

  @override
  Future<Result<Unit>> deletePlaylist(String playlistId) =>
      _answer('deletePlaylist($playlistId)');
}

/// Importador falso: devuelve [result] (o lanza [error]) y avisa del
/// progreso con [progress].
class FakePlaylistImporter implements IPlaylistImporter {
  Result<ImportResult> result = const Ok(
    ImportResult(playlistId: 'p1', imported: 1, skipped: 0),
  );
  Object? error;
  List<(int, int)> progress = const [];
  final List<String> calls = [];

  @override
  Future<Result<ImportResult>> importFromUrl(
    String urlOrId, {
    ImportProgress? onProgress,
  }) async {
    calls.add(urlOrId);
    if (error case final e?) throw e;
    for (final (done, total) in progress) {
      onProgress?.call(done, total);
    }
    return result;
  }
}

/// Sincronización falsa de "Me encanta": registra las canciones.
class FakeLikedPlaylistSync implements ILikedPlaylistSync {
  Result<Unit> result = const Ok(unit);
  final List<Song> synced = [];

  static const failure = DatabaseFailure('sync failed');

  @override
  Future<Result<Unit>> sync(Song song) async {
    synced.add(song);
    return result;
  }
}

/// Origen de Spotify falso: devuelve [result] y registra los ids pedidos.
class FakeSpotifyPlaylistSource implements ISpotifyPlaylistSource {
  Result<RemotePlaylist> result = const Ok(
    RemotePlaylist(name: 'Mix', tracks: []),
  );
  final List<String> calls = [];

  @override
  Future<Result<RemotePlaylist>> fetch(String playlistId) async {
    calls.add(playlistId);
    return result;
  }
}

/// Emparejador falso: responde con [answer] (por defecto, una canción de
/// YouTube con el título de la pista) o lanza [error]; registra las pistas.
class FakeTrackMatcher implements ITrackMatcher {
  Future<Result<Song?>> Function(RemoteTrack track)? answer;
  Object? error;
  final List<RemoteTrack> calls = [];

  @override
  Future<Result<Song?>> match(RemoteTrack track) async {
    calls.add(track);
    if (error case final e?) throw e;
    if (answer case final a?) return a(track);
    return Ok(
      Song(
        id: '',
        title: track.title,
        artist: track.artists.join(', '),
        durationMs: track.durationMs,
        source: SongSource.youtube,
        sourceId: 'yt-${track.title}',
      ),
    );
  }
}
