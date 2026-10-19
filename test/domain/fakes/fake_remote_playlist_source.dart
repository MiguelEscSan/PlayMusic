import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/sources/i_remote_playlist_source.dart';
import 'package:koda/sources/youtube/youtube_playlist_source.dart';

/// Playlist remota falsa: lee lo que diga [_fetch] y reconoce los enlaces
/// como YouTube.
class FakeRemotePlaylistSource implements IRemotePlaylistSource {
  FakeRemotePlaylistSource(this._fetch);

  final Future<(String, List<Song?>)> Function(String playlistId) _fetch;

  @override
  String? parsePlaylistId(String urlOrId) =>
      YoutubePlaylistSource.create().parsePlaylistId(urlOrId);

  @override
  Future<RemoteSongPlaylist> fetch(
    String playlistId, {
    required int maxSongs,
  }) async {
    final (title, songs) = await _fetch(playlistId);
    return (title: title, songs: songs);
  }
}
