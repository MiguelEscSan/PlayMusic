import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/domain/usecases/cancel_download_use_case.dart';
import '../features/downloads/domain/usecases/delete_all_downloads_use_case.dart';
import '../features/downloads/domain/usecases/delete_download_use_case.dart';
import '../features/downloads/domain/usecases/download_all_use_case.dart';
import '../features/downloads/domain/usecases/download_song_use_case.dart';
import '../features/downloads/domain/usecases/get_downloaded_songs_use_case.dart';
import '../features/downloads/domain/usecases/watch_download_tasks_use_case.dart';
import '../features/downloads/domain/usecases/watch_downloads_changed_use_case.dart';
import '../features/export/domain/usecases/export_song_use_case.dart';
import '../features/favorites/domain/usecases/get_liked_songs_use_case.dart';
import '../features/favorites/domain/usecases/toggle_like_use_case.dart';
import '../features/history/domain/usecases/clear_history_use_case.dart';
import '../features/history/domain/usecases/get_recent_songs_use_case.dart';
import '../features/history/domain/usecases/get_top_songs_use_case.dart';
import '../features/history/domain/usecases/watch_history_changed_use_case.dart';
import '../features/lyrics/domain/usecases/get_lyrics_use_case.dart';
import '../features/player/domain/usecases/add_to_queue_use_case.dart';
import '../features/player/domain/usecases/cycle_repeat_mode_use_case.dart';
import '../features/player/domain/usecases/move_in_queue_use_case.dart';
import '../features/player/domain/usecases/pause_playback_use_case.dart';
import '../features/player/domain/usecases/play_next_use_case.dart';
import '../features/player/domain/usecases/play_queue_use_case.dart';
import '../features/player/domain/usecases/play_shuffled_use_case.dart';
import '../features/player/domain/usecases/remove_from_queue_use_case.dart';
import '../features/player/domain/usecases/seek_use_case.dart';
import '../features/player/domain/usecases/set_stop_after_current_use_case.dart';
import '../features/player/domain/usecases/skip_to_next_use_case.dart';
import '../features/player/domain/usecases/skip_to_previous_song_use_case.dart';
import '../features/player/domain/usecases/skip_to_previous_use_case.dart';
import '../features/player/domain/usecases/skip_to_queue_index_use_case.dart';
import '../features/player/domain/usecases/toggle_play_pause_use_case.dart';
import '../features/player/domain/usecases/toggle_shuffle_use_case.dart';
import '../features/player/domain/usecases/watch_player_position_use_case.dart';
import '../features/player/domain/usecases/watch_player_snapshot_use_case.dart';
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
import '../features/search/domain/usecases/clear_recent_searches_use_case.dart';
import '../features/search/domain/usecases/get_recent_searches_use_case.dart';
import '../features/search/domain/usecases/get_suggestions_use_case.dart';
import '../features/search/domain/usecases/record_search_use_case.dart';
import '../features/search/domain/usecases/remove_recent_search_use_case.dart';
import '../features/search/domain/usecases/search_songs_use_case.dart';
import '../features/settings/domain/usecases/get_download_only_wifi_use_case.dart';
import '../features/settings/domain/usecases/get_radio_enabled_use_case.dart';
import '../features/settings/domain/usecases/set_download_only_wifi_use_case.dart';
import '../features/settings/domain/usecases/set_radio_enabled_use_case.dart';
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

// ---------------------------------------------------------------------------
// Reproductor y cola
// ---------------------------------------------------------------------------

final watchPlayerSnapshotUseCaseProvider = Provider<WatchPlayerSnapshotUseCase>(
  (ref) => WatchPlayerSnapshotUseCase(ref.watch(audioPlayerServiceProvider)),
);

final watchPlayerPositionUseCaseProvider = Provider<WatchPlayerPositionUseCase>(
  (ref) => WatchPlayerPositionUseCase(ref.watch(audioPlayerServiceProvider)),
);

final playQueueUseCaseProvider = Provider<PlayQueueUseCase>(
  (ref) => PlayQueueUseCase(
    ref.watch(songRepositoryProvider),
    ref.watch(audioPlayerServiceProvider),
  ),
);

final playShuffledUseCaseProvider = Provider<PlayShuffledUseCase>(
  (ref) => PlayShuffledUseCase(
    ref.watch(songRepositoryProvider),
    ref.watch(audioPlayerServiceProvider),
  ),
);

final playNextUseCaseProvider = Provider<PlayNextUseCase>(
  (ref) => PlayNextUseCase(
    ref.watch(songRepositoryProvider),
    ref.watch(audioPlayerServiceProvider),
  ),
);

final addToQueueUseCaseProvider = Provider<AddToQueueUseCase>(
  (ref) => AddToQueueUseCase(
    ref.watch(songRepositoryProvider),
    ref.watch(audioPlayerServiceProvider),
  ),
);

final togglePlayPauseUseCaseProvider = Provider<TogglePlayPauseUseCase>(
  (ref) => TogglePlayPauseUseCase(ref.watch(audioPlayerServiceProvider)),
);

final skipToNextUseCaseProvider = Provider<SkipToNextUseCase>(
  (ref) => SkipToNextUseCase(ref.watch(audioPlayerServiceProvider)),
);

final skipToPreviousUseCaseProvider = Provider<SkipToPreviousUseCase>(
  (ref) => SkipToPreviousUseCase(ref.watch(audioPlayerServiceProvider)),
);

final skipToPreviousSongUseCaseProvider = Provider<SkipToPreviousSongUseCase>(
  (ref) => SkipToPreviousSongUseCase(ref.watch(audioPlayerServiceProvider)),
);

final skipToQueueIndexUseCaseProvider = Provider<SkipToQueueIndexUseCase>(
  (ref) => SkipToQueueIndexUseCase(ref.watch(audioPlayerServiceProvider)),
);

final seekUseCaseProvider = Provider<SeekUseCase>(
  (ref) => SeekUseCase(ref.watch(audioPlayerServiceProvider)),
);

final toggleShuffleUseCaseProvider = Provider<ToggleShuffleUseCase>(
  (ref) => ToggleShuffleUseCase(ref.watch(audioPlayerServiceProvider)),
);

final cycleRepeatModeUseCaseProvider = Provider<CycleRepeatModeUseCase>(
  (ref) => CycleRepeatModeUseCase(ref.watch(audioPlayerServiceProvider)),
);

final moveInQueueUseCaseProvider = Provider<MoveInQueueUseCase>(
  (ref) => MoveInQueueUseCase(ref.watch(audioPlayerServiceProvider)),
);

final removeFromQueueUseCaseProvider = Provider<RemoveFromQueueUseCase>(
  (ref) => RemoveFromQueueUseCase(ref.watch(audioPlayerServiceProvider)),
);

// Temporizador de apagado.

final pausePlaybackUseCaseProvider = Provider<PausePlaybackUseCase>(
  (ref) => PausePlaybackUseCase(ref.watch(audioPlayerServiceProvider)),
);

final setStopAfterCurrentUseCaseProvider = Provider<SetStopAfterCurrentUseCase>(
  (ref) => SetStopAfterCurrentUseCase(ref.watch(audioPlayerServiceProvider)),
);

// ---------------------------------------------------------------------------
// Ajustes
// ---------------------------------------------------------------------------

final getRadioEnabledUseCaseProvider = Provider<GetRadioEnabledUseCase>(
  (ref) => GetRadioEnabledUseCase(ref.watch(settingsRepositoryProvider)),
);

final setRadioEnabledUseCaseProvider = Provider<SetRadioEnabledUseCase>(
  (ref) => SetRadioEnabledUseCase(ref.watch(settingsRepositoryProvider)),
);

final getDownloadOnlyWifiUseCaseProvider = Provider<GetDownloadOnlyWifiUseCase>(
  (ref) => GetDownloadOnlyWifiUseCase(ref.watch(settingsRepositoryProvider)),
);

final setDownloadOnlyWifiUseCaseProvider = Provider<SetDownloadOnlyWifiUseCase>(
  (ref) => SetDownloadOnlyWifiUseCase(ref.watch(settingsRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Historial de escucha
// ---------------------------------------------------------------------------

final getTopSongsUseCaseProvider = Provider<GetTopSongsUseCase>(
  (ref) => GetTopSongsUseCase(ref.watch(historyRepositoryProvider)),
);

final getRecentSongsUseCaseProvider = Provider<GetRecentSongsUseCase>(
  (ref) => GetRecentSongsUseCase(ref.watch(historyRepositoryProvider)),
);

final clearHistoryUseCaseProvider = Provider<ClearHistoryUseCase>(
  (ref) => ClearHistoryUseCase(
    ref.watch(historyRepositoryProvider),
    ref.watch(historyEventsProvider),
  ),
);

final watchHistoryChangedUseCaseProvider = Provider<WatchHistoryChangedUseCase>(
  (ref) => WatchHistoryChangedUseCase(ref.watch(historyEventsProvider)),
);

// ---------------------------------------------------------------------------
// Búsqueda
// ---------------------------------------------------------------------------

final searchSongsUseCaseProvider = Provider<SearchSongsUseCase>(
  (ref) => SearchSongsUseCase(ref.watch(searchSourceProvider)),
);

final getSuggestionsUseCaseProvider = Provider<GetSuggestionsUseCase>(
  (ref) => GetSuggestionsUseCase(ref.watch(suggestionSourceProvider)),
);

final getRecentSearchesUseCaseProvider = Provider<GetRecentSearchesUseCase>(
  (ref) => GetRecentSearchesUseCase(ref.watch(searchHistoryRepositoryProvider)),
);

final recordSearchUseCaseProvider = Provider<RecordSearchUseCase>(
  (ref) => RecordSearchUseCase(ref.watch(searchHistoryRepositoryProvider)),
);

final removeRecentSearchUseCaseProvider = Provider<RemoveRecentSearchUseCase>(
  (ref) =>
      RemoveRecentSearchUseCase(ref.watch(searchHistoryRepositoryProvider)),
);

final clearRecentSearchesUseCaseProvider = Provider<ClearRecentSearchesUseCase>(
  (ref) =>
      ClearRecentSearchesUseCase(ref.watch(searchHistoryRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Letras y exportar
// ---------------------------------------------------------------------------

final getLyricsUseCaseProvider = Provider<GetLyricsUseCase>(
  (ref) => GetLyricsUseCase(ref.watch(lyricsRepositoryProvider)),
);

final exportSongUseCaseProvider = Provider<ExportSongUseCase>(
  (ref) => ExportSongUseCase(ref.watch(songExporterProvider)),
);
