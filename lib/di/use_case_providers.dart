import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/favorites/domain/usecases/toggle_favorite_use_case.dart';
import '../features/playlists/domain/usecases/add_song_to_playlist_use_case.dart';
import '../features/playlists/domain/usecases/remove_song_from_playlist_use_case.dart';
import 'data_providers.dart';

final toggleFavoriteUseCaseProvider = Provider<ToggleFavoriteUseCase>(
  (ref) => ToggleFavoriteUseCase(ref.watch(songRepositoryProvider)),
);

final addSongToPlaylistUseCaseProvider = Provider<AddSongToPlaylistUseCase>(
  (ref) => AddSongToPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final removeSongFromPlaylistUseCaseProvider =
    Provider<RemoveSongFromPlaylistUseCase>(
      (ref) =>
          RemoveSongFromPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
    );
