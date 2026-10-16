import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/favorites/data/liked_playlist.dart';

/// En la app `likedPlaylistProvider` se sobrescribe con la instancia de
/// `bootstrap()`. En los tests se construye sobre los repositorios (o DAOs)
/// que cada test sobrescribe.
final Override likedPlaylistFromRepositories = likedPlaylistProvider
    .overrideWith(
      (ref) => LikedPlaylist(
        playlists: ref.watch(playlistRepositoryProvider),
        songs: ref.watch(songRepositoryProvider),
        settings: ref.watch(settingsRepositoryProvider),
      ),
    );
