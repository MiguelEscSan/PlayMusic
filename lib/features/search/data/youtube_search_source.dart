import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/domain/entities/song.dart';
import '../domain/search_source.dart';

/// Búsqueda en YouTube con youtube_explode_dart (20 resultados por página).
class YoutubeSearchSource implements SearchSource {
  YoutubeSearchSource(this._yt);

  final YoutubeExplode _yt;

  /// Vídeos más largos que esto casi nunca son canciones (directos,
  /// recopilatorios de horas…).
  static const _maxDuration = Duration(minutes: 20);

  @override
  Future<SearchPage> search(String query) async =>
      _toPage(await _yt.search.search(query));

  SearchPage _toPage(VideoSearchList list) {
    final songs = list.map(songFromVideo).whereType<Song>().toList();
    return SearchPage(songs, () async {
      final next = await list.nextPage();
      return next == null ? const SearchPage([], null) : _toPage(next);
    });
  }

  /// Convierte un vídeo en canción; null si no lo parece (directo, sin
  /// duración o demasiado largo).
  static Song? songFromVideo(Video v) {
    final duration = v.duration;
    if (v.isLive || duration == null || duration > _maxDuration) return null;
    return Song(
      id: '', // se asigna al guardarla en la BD
      title: cleanTitle(v.title),
      artist: cleanArtist(v.author),
      durationMs: duration.inMilliseconds,
      artworkUrl: v.thumbnails.highResUrl,
      source: SongSource.youtube,
      sourceId: v.id.value,
    );
  }

  static final _junk = RegExp(
    r'\s*[\(\[][^\)\]]*\b(official|oficial|video|lyrics?|letra|audio|'
    r'visualizer|hd|4k|mv)\b[^\)\]]*[\)\]]',
    caseSensitive: false,
  );

  /// Quita el "(Official Video)", "[Lyrics]", etc. del título.
  static String cleanTitle(String title) {
    final cleaned = title.replaceAll(_junk, '').trim();
    return cleaned.isEmpty ? title : cleaned;
  }

  /// Los canales automáticos de YouTube Music se llaman "Artista - Topic".
  static String cleanArtist(String author) => author
      .replaceAll(RegExp(r'\s+-\s+Topic$'), '')
      .replaceAll(RegExp(r'VEVO$'), '')
      .trim();
}
