import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/domain/usecases/cancel_download_use_case.dart';
import '../features/downloads/domain/usecases/delete_all_downloads_use_case.dart';
import '../features/downloads/domain/usecases/delete_download_use_case.dart';
import '../features/downloads/domain/usecases/download_all_use_case.dart';
import '../features/downloads/domain/usecases/download_song_use_case.dart';
import '../features/downloads/domain/usecases/get_downloaded_songs_use_case.dart';
import '../features/downloads/domain/usecases/watch_download_tasks_use_case.dart';
import '../features/downloads/domain/usecases/watch_downloads_changed_use_case.dart';
import '../features/favorites/domain/usecases/get_liked_songs_use_case.dart';
import '../features/favorites/domain/usecases/toggle_like_use_case.dart';
import '../features/playlists/domain/usecases/add_song_to_playlist_use_case.dart';
import '../features/playlists/domain/usecases/clear_playlist_cover_use_case.dart';
import '../features/playlists/domain/usecases/create_playlist_use_case.dart';
import '../features/playlists/domain/usecases/delete_playlist_use_case.dart';
import '../features/playlists/domain/usecases/get_playlist_use_case.dart';
import '../features/playlists/domain/usecases/get_playlists_use_case.dart';
import '../features/playlists/domain/usecases/import_youtube_playlist_use_case.dart';
import '../features/playlists/domain/usecases/move_song_in_playlist_use_case.dart';
import '../features/playlists/domain/usecases/remove_song_at_use_case.dart';
import '../features/playlists/domain/usecases/rename_playlist_use_case.dart';
import '../features/playlists/domain/usecases/restore_song_at_use_case.dart';
import '../features/playlists/domain/usecases/set_playlist_cover_from_file_use_case.dart';
import 'data_providers.dart';
import 'service_providers.dart';

// Casos de uso: lo único que llama la capa de presentación. Cada uno se
// construye sobre las interfaces de dominio que exponen los demás
// providers, así que en los tests basta con sobrescribir el repositorio,
// DAO o servicio que se quiera falsear.

// ---------------------------------------------------------------------------
// Playlists
// ---------------------------------------------------------------------------

final getPlaylistsUseCaseProvider = Provider<GetPlaylistsUseCase>(
  (ref) => GetPlaylistsUseCase(ref.watch(playlistRepositoryProvider)),
);

final getPlaylistUseCaseProvider = Provider<GetPlaylistUseCase>(
  (ref) => GetPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final createPlaylistUseCaseProvider = Provider<CreatePlaylistUseCase>(
  (ref) => CreatePlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final renamePlaylistUseCaseProvider = Provider<RenamePlaylistUseCase>(
  (ref) => RenamePlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final deletePlaylistUseCaseProvider = Provider<DeletePlaylistUseCase>(
  (ref) => DeletePlaylistUseCase(ref.watch(playlistCoverServiceProvider)),
);

final setPlaylistCoverFromFileUseCaseProvider =
    Provider<SetPlaylistCoverFromFileUseCase>(
      (ref) => SetPlaylistCoverFromFileUseCase(
        ref.watch(playlistCoverServiceProvider),
      ),
    );

final clearPlaylistCoverUseCaseProvider = Provider<ClearPlaylistCoverUseCase>(
  (ref) => ClearPlaylistCoverUseCase(ref.watch(playlistCoverServiceProvider)),
);

final importYoutubePlaylistUseCaseProvider =
    Provider<ImportYoutubePlaylistUseCase>(
      (ref) => ImportYoutubePlaylistUseCase(
        ref.watch(youtubePlaylistImporterProvider),
      ),
    );

final addSongToPlaylistUseCaseProvider = Provider<AddSongToPlaylistUseCase>(
  (ref) => AddSongToPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final removeSongAtUseCaseProvider = Provider<RemoveSongAtUseCase>(
  (ref) => RemoveSongAtUseCase(ref.watch(playlistRepositoryProvider)),
);

final moveSongInPlaylistUseCaseProvider = Provider<MoveSongInPlaylistUseCase>(
  (ref) => MoveSongInPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final restoreSongAtUseCaseProvider = Provider<RestoreSongAtUseCase>(
  (ref) => RestoreSongAtUseCase(ref.watch(playlistRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Favoritas
// ---------------------------------------------------------------------------

final getLikedSongsUseCaseProvider = Provider<GetLikedSongsUseCase>(
  (ref) => GetLikedSongsUseCase(ref.watch(songRepositoryProvider)),
);

final toggleLikeUseCaseProvider = Provider<ToggleLikeUseCase>(
  (ref) => ToggleLikeUseCase(
    ref.watch(songRepositoryProvider),
    ref.watch(likedPlaylistProvider),
  ),
);

// ---------------------------------------------------------------------------
// Descargas
// ---------------------------------------------------------------------------

final getDownloadedSongsUseCaseProvider = Provider<GetDownloadedSongsUseCase>(
  (ref) => GetDownloadedSongsUseCase(ref.watch(songRepositoryProvider)),
);

final watchDownloadTasksUseCaseProvider = Provider<WatchDownloadTasksUseCase>(
  (ref) => WatchDownloadTasksUseCase(ref.watch(downloadServiceProvider)),
);

final watchDownloadsChangedUseCaseProvider =
    Provider<WatchDownloadsChangedUseCase>(
      (ref) => WatchDownloadsChangedUseCase(ref.watch(downloadServiceProvider)),
    );

final downloadSongUseCaseProvider = Provider<DownloadSongUseCase>(
  (ref) => DownloadSongUseCase(ref.watch(downloadServiceProvider)),
);

final downloadAllUseCaseProvider = Provider<DownloadAllUseCase>(
  (ref) => DownloadAllUseCase(ref.watch(downloadServiceProvider)),
);

final cancelDownloadUseCaseProvider = Provider<CancelDownloadUseCase>(
  (ref) => CancelDownloadUseCase(ref.watch(downloadServiceProvider)),
);

final deleteDownloadUseCaseProvider = Provider<DeleteDownloadUseCase>(
  (ref) => DeleteDownloadUseCase(ref.watch(downloadServiceProvider)),
);

final deleteAllDownloadsUseCaseProvider = Provider<DeleteAllDownloadsUseCase>(
  (ref) => DeleteAllDownloadsUseCase(ref.watch(downloadServiceProvider)),
);
