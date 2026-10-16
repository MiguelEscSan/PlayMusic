import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';

/// Favoritas fijas, sin repositorio: `likedSongsProvider.overrideWith(...)`.
class FixedLikedSongs extends LikedSongsNotifier {
  FixedLikedSongs([this.songs = const []]);

  final List<Song> songs;

  @override
  Future<List<Song>> build() async => songs;
}

/// Descargas fijas, sin repositorio ni `DownloadManager`:
/// `downloadedSongsProvider.overrideWith(...)`.
class FixedDownloads extends DownloadsNotifier {
  FixedDownloads([this.songs = const []]);

  final List<Song> songs;

  @override
  Future<List<Song>> build() async => songs;
}
