import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/models/song.dart';
import '../../search/data/youtube_search_source.dart';
import 'playlist_dao.dart';

/// Descarga el título y los vídeos de una playlist de YouTube. Cada vídeo
/// que no parezca una canción (directo, sin duración…) llega como null.
typedef YoutubePlaylistFetcher =
    Future<(String title, List<Song?> songs)> Function(String playlistId);

/// Resultado de una importación.
class ImportResult {
  const ImportResult({
    required this.playlistId,
    required this.imported,
    required this.skipped,
  });

  final String playlistId;
  final int imported;

  /// Vídeos omitidos: no disponibles como canción o repetidos.
  final int skipped;
}

/// El texto pegado no es un enlace de playlist de YouTube.
class InvalidPlaylistLinkException implements Exception {
  const InvalidPlaylistLinkException();

  @override
  String toString() => 'El enlace no es de una playlist de YouTube';
}

/// La playlist no tiene ninguna canción que se pueda importar.
class EmptyPlaylistException implements Exception {
  const EmptyPlaylistException();

  @override
  String toString() => 'La playlist no tiene canciones que importar';
}

/// Crea una playlist local a partir de una de YouTube, con el mismo título y
/// las canciones en el mismo orden.
class YoutubePlaylistImporter {
  YoutubePlaylistImporter(this._dao, this._fetch);

  /// Versión real. [client] se llama solo al importar, para no crear el
  /// cliente de YouTube hasta que haga falta (no se cierra aquí).
  factory YoutubePlaylistImporter.youtube(
    PlaylistDao dao,
    YoutubeExplode Function() client,
  ) => YoutubePlaylistImporter(dao, (id) async {
    final yt = client();
    final playlist = await yt.playlists.get(id);
    final videos = await yt.playlists.getVideos(id).take(maxSongs).toList();
    return (
      playlist.title,
      videos.map(YoutubeSearchSource.songFromVideo).toList(),
    );
  });

  /// Límite de canciones por importación, para no eternizarse.
  static const maxSongs = 500;

  final PlaylistDao _dao;
  final YoutubePlaylistFetcher _fetch;

  /// Acepta el enlace completo o solo el id. Lanza
  /// [InvalidPlaylistLinkException] si no es válido y
  /// [EmptyPlaylistException] si no hay nada que importar; en ambos casos no
  /// se crea ninguna playlist.
  Future<ImportResult> importFromUrl(
    String urlOrId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final id = PlaylistId.parsePlaylistId(urlOrId.trim());
    if (id == null) throw const InvalidPlaylistLinkException();

    final (title, fetched) = await _fetch(id);
    final videos = fetched.take(maxSongs).toList();
    if (videos.every((s) => s == null)) throw const EmptyPlaylistException();

    final name = title.trim().isEmpty ? 'Playlist de YouTube' : title;
    final playlist = await _dao.create(name);
    var imported = 0;
    onProgress?.call(0, videos.length);
    for (var i = 0; i < videos.length; i++) {
      final song = videos[i];
      if (song != null && await _dao.addSong(playlist.id, song)) imported++;
      onProgress?.call(i + 1, videos.length);
    }
    return ImportResult(
      playlistId: playlist.id,
      imported: imported,
      skipped: videos.length - imported,
    );
  }
}
