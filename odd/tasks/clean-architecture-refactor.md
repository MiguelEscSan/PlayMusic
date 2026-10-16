# Clean Architecture refactor

## Objective
Refactor Koda to strict Clean Architecture: pure domain, data layer behind
repository interfaces returning typed results, and Riverpod notifiers owning
all state mutation.

## Problem
- UI depends on concrete DAOs (`ref.read(daoProvider).method()`).
- SQLite serialization (`toMap`/`fromMap`) lives in the entities.
- Business logic mutates state inside `StatefulWidget`s (e.g. `PlaylistDetailScreen`).
- DAOs broadcast global changes through `StreamController`s (mixed responsibilities).

## Constraints
- Executed phase by phase; the user confirms between phases.
- Error handling: native Dart 3 sealed `Result<T>` (`Ok`/`Err`) + sealed `Failure`. No new packages.
- Domain entity keeps the name `Song`/`Playlist` (used in ~70 files); the data layer gets `SongModel`/`PlaylistModel`.
- `downloadProgress` is transient UI state and is excluded from the domain entity.
- Phase 1 only adds files; existing code is untouched and keeps compiling.

## Delivery
- Branch: `refactor/clean-architecture`. Strategy: `ask-on-risk`.

## Tasks

### Phase 1 — Domain isolation
- [x] P1.1 `Failure` hierarchy + `Result<T>` (`lib/core/error/`)
- [x] P1.2 Pure entities `Song`, `Playlist`, `SongSource` (`lib/core/domain/entities/`)
- [x] P1.3 Interfaces `ISongRepository`, `IPlaylistRepository` (`lib/core/domain/repositories/`)
- [x] P1.4 Use cases `AddSongToPlaylistUseCase`, `RemoveSongFromPlaylistUseCase`, `ToggleFavoriteUseCase` with fake-repository tests

Route: delegated direct (writer trigger: 2+ non-trivial files).

### Phase 2 — Data layer
Decision (user, 2026-10-16): DAO `StreamController` removal moved to Phase 3 —
5 StreamProviders and PlaylistDao→SongDao re-emission depend on `changes`;
removing it before notifiers own invalidation would break reactivity.

Slice 2a (additive, no consumer edits):
- [x] P2.1 Move current models to `lib/core/data/models/` as `SongModel`/`PlaylistModel` (same SQLite logic) + `toEntity`/`fromEntity` mappers; legacy `lib/core/models/*.dart` become `typedef` shims so consumers compile unchanged
- [x] P2.3 `SongRepositoryImpl`/`PlaylistRepositoryImpl` over the DAOs, returning `Result` (sqflite errors → `DatabaseFailure`, missing → `NotFoundFailure`)

Slice 2b:
- [x] P2.4 Services (`DownloadManager`, `RadioService`, `LikedPlaylist`, `PlaylistCoverService`, importer, `SongActions`) depend on interfaces + domain `Song`; repository providers; remove legacy shims

### Phase 3 — Presentation (pending user go-ahead)
- [x] F1 (review 2b) `playlist_detail_screen.dart` swallows Err from removeSongAt/addSong/moveSong (optimistic UI desync) — resolve via notifier + error state (P3.2/P3.3)
- [x] F2 (review 2b) `DownloadManager`: markDownloaded Err leaves the renamed file on disk untracked — delete it on Err + test
- [x] F3 (review 2b) `PlaylistCoverService.setFromFile`: copied cover leaks when findById/setCover returns Err — delete it on Err + test
- [x] F4 (review 2b) `LikedPlaylist._ensure`: playlist id persisted before backfill; getLiked/addSong Err leaves "Me encanta" permanently incomplete — persist id after backfill + test
- [x] F5 (review 2b, suggestion) `SongActions.toggleLike`: Err after like already changed is ambiguous — document or return partial result
- [x] F6 (review 3b, WARNING) PlaylistDetailNotifier._optimistic restores a full snapshot on Err; overlapping mutations resurrect rows already removed in the DB — on Err reload from the repository (or serialize mutations) + overlapping-mutation test
- [x] F7 (review 3b, suggestion) detail rebuild via downloadedKeysProvider during a pending optimistic write — pin interleaving with a test / guard with ref.mounted
- [x] F8 (review 3c, WARNING) bootstrap onLocalFileMissing reads late `downloads` before assignment -> LateInitializationError during initAudio; make it safe + test
- [x] F9 (review 3c, WARNING) LikedSongsNotifier not refreshed on downloadsChanged -> stale localPath in liked list; listen like DownloadsNotifier + test
- [x] F10 (review 3c, suggestion) widget tests for error UI (DownloadsScreen ErrorView/retry, deleteAll SnackBar, LikeButton/SongTile/DownloadButton SnackBars)
- [ ] F11 (review fde02d4..007b9ed, suggestion) test that bootstrap attaches the DownloadManager to LocalFileMissingHandler (lib/bootstrap.dart:103)
- [ ] F12 (review fde02d4..007b9ed, suggestion) local_file_missing_handler_test Err-with-manager case should assert the song stays downloaded and no downloadsChanged is emitted
- [x] P2.2 (moved) Remove `StreamController` from DAOs; reactivity owned by notifiers
- [x] P3.1 Notifiers for playlists, playlist detail, favorites, downloads
- [x] P3.2 Refactor `PlaylistDetailScreen` and `DownloadsScreen` to notifiers
- [x] P3.3 Error states rendered from `Result`

## Acceptance criteria (Phase 1)
- Domain files import nothing from Flutter, sqflite or data layers (only `dart:` libraries; `meta`/`collection` are not direct deps).
- Use cases depend only on repository interfaces and are covered by unit tests.
- `flutter analyze` clean on new files; `flutter test test/domain` green.

## Progress
- 2026-10-16: branch created, Phase 1 started.
- 2026-10-16: Phase 1 done (delegated writer). RED: usecases_test failed to compile before use cases existed. GREEN: `flutter test test/domain` +33 passed (parent re-ran). `flutter analyze` scoped: no issues; whole project 31 issues = baseline. Flutter SDK at C:/dev/flutter (not on PATH); package name `sponify`.
- 2026-10-16: Phase 1 commit 0fcc512. Review assess: medium (slice_budget_reached, 1005 lines). Native review consent: declined by user; off-path medium tier = writer self-verification + parent spot check (`flutter test test/domain` +33 re-run). Reviewed boundary stays at main.
- Next: Phase 2 (data layer), pending user go-ahead.
- 2026-10-16: Slice 2a done (delegated writer). RED: test/data failed to compile before repos existed. GREEN: `flutter test test/data` +19 (parent re-ran with models/playlist_dao tests: +32). Full suite +257/-3; the 3 failures (history_section_test "pinta el título...", song_swipe_test "playlist derecha encola...", widget_test "Me gusta...") fail identically on ef55fb9 → pre-existing, not caused by this slice. analyze: 31 = baseline.
- Known pre-existing failures: the 3 widget tests above.
- 2026-10-16: Slice 2a commit c0cdc4e. Review assess: medium (slice_budget_reached, 2340 lines cumulative from main). Native review consent: declined by user; medium off-path = writer self-verification + parent spot check. Reviewed boundary stays at main.
- 2026-10-17: Slice 2b done (delegated writer, interrupted by machine shutdown; parent reconciled the working tree). Services depend on ISongRepository/IPlaylistRepository + domain Song; DI in lib/core/di/repository_providers.dart; SongActions.toggleLike uses ToggleFavoriteUseCase; StreamProviders fetch via repositories and surface Err as AsyncError via transitional unwrapOrThrow; legacy shims and test/models_test.dart removed. Interfaces gained findBySource, markDownloaded, setCover. Verification (parent): flutter analyze 31 = baseline; full suite +259/-3 (same 3 known pre-existing failures); focused data/domain/download/liked tests +74 after dart format. test/history_dao_test.dart: only import + 2 type lines committed; user reflow left unstaged.
- Next: Phase 3 (P2.2 stream removal + notifiers), pending user go-ahead.
- 2026-10-17: Slice 2b commit 8f6cf46. Full-range candidate (main..HEAD, 3727 lines) stopped with lens_context_budget_exceeded (no authority created); reduced to slice 2b only (base d559ebc, 1421 lines): consent granted, 1 lens (review-reliability), APPROVED, acknowledged (lineage review-848903210a6720eb, authority burned). Reviewed boundary advances to 8f6cf46. 4 WARNING + 1 SUGGESTION informational findings recorded as F1-F5 in Phase 3.
- 2026-10-17: Slice 3a (F2-F4) done (delegated writer). RED/GREEN observed per bug: F2 file left on disk after markDownloaded Err -> deleted; F3 copied cover leaked on Err -> deleted via _deleteOwned; F4 id persisted before backfill -> persisted after, created playlist deleted on backfill Err (residual: if that delete fails an unlinked playlist remains). Parent re-ran the 3 test files: +25. Full suite +262/-3 (known failures). analyze 31 = baseline.
- 2026-10-17: Slice 3a commit e6f8e9b. Review assess (base 8f6cf46): medium, 230 lines, review_due=false (under_budget) — pending in slice until the next commits reach the budget. Reviewed boundary stays 8f6cf46.
- 2026-10-17: Slice 3b (playlists half of P2.2/P3.1-P3.3 + F1) done (delegated writer). PlaylistDao is pure CRUD (no StreamController, no SongDao subscription). playlistsProvider = AsyncNotifier (create/rename/delete/setCoverFromFile/clearCover/addSong/importFromYoutube, all Result); playlistProvider = autoDispose family AsyncNotifier (removeSongAt/addSong/move/rename) with optimistic update + rollback on Err (F1; RED "Expected 3 songs, Actual 2" -> GREEN). Bridges: toggleLike invalidates playlist providers; builds watch a select signature of downloadedKeysProvider. retry disabled (Riverpod 3 retries thrown Failures). ErrorView for load errors, SnackBar for mutation Err. song_swipe known failure fixed (test screen too short). Parent re-ran test/playlists + song_swipe: +40. Full suite +295/-2 (history_section, widget_test "Me gusta" known). analyze 31.
- 2026-10-17: Slice 3b commit a32326d. Review (base 8f6cf46 = 3a+3b, 1581 lines): consent granted, 1 lens review-reliability, APPROVED, acknowledged (lineage review-95e2f15b6989137b). Reviewed boundary advances to a32326d. Findings recorded as F6 (warning) and F7 (suggestion).
- 2026-10-17: Slice 3c done (delegated writer). SongDao pure CRUD (no StreamController). DownloadsNotifier (downloadedSongsProvider; delete/deleteAll via DownloadManager, reload after Err) bridged by new DownloadManager.downloadsChanged stream (completed/deleted/forgetMissingFile; bootstrap onLocalFileMissing -> forgetMissingFile). LikedSongsNotifier invalidated by SongActions.toggleLike. downloadsSizeProvider derived from list. unwrapOrThrow removed; noAutomaticRetry moved to repository_providers. F6/F7: no snapshot restore — pending/stale counters, resync from repository when last write ends (RED: Expected [T1,T2] Actual [T0,T1,T2] -> GREEN). Parent re-ran test/downloads+favorites+playlists: +49. Full suite +312/-2 (known: history_section; widget_test "Me gusta" is stale — commit 88afcd7 removed likedHomeSection from home). analyze 31.
- 2026-10-17: Slice 3c commit f6012a7. Review (base a32326d, 1134 lines): consent granted, 1 lens review-reliability, APPROVED, acknowledged (lineage review-a7509c2ed5184fd3). Reviewed boundary advances to f6012a7. Findings F8, F9 (warnings, introduced) and F10 (suggestion).
- 2026-10-17: F8/F9 fixed (delegated writer). F8: LocalFileMissingHandler (nullable manager; falls back to songRepository.clearDownload before DownloadManager exists — reorder impossible due to DownloadManager -> audio.onSongStorageChanged -> initAudio -> resolver cycle); RED compile-failure, GREEN +4. F9: LikedSongsNotifier subscribes to downloadsChanged; RED timeout, GREEN. Playlists already refresh via downloadedKeysProvider. Full suite +317/-2 (known). analyze 31.
- 2026-10-17: Fix commit fde02d4 assess (base f6012a7): medium, 275 lines, under_budget (pending in slice). Phase 3 complete except F5 (suggestion) and F10 (suggestion, widget tests for error UI). Branch: 14 commits, 106 files, +5148/-717 vs main — delivery needs chained PRs (user decision).
- 2026-10-16: F10 done in test/error_feedback_test.dart (6 widget tests: DownloadsScreen ErrorView + "Reintentar", deleteAll SnackBar in Downloads and Settings, DownloadButton delete SnackBar, LikeButton/SongTile like SnackBar), forcing Err with FlakySongRepository shared by songRepositoryProvider and DownloadManager. Mutation check: removing each error branch in lib makes all 6 fail. Known failures fixed: history_section_test was stale since 88afcd7 (RecentHomeSection uses SongTile, subtitle "artist · duration"); widget_test "Me gusta" now asserts the "Me encanta" playlist on Inicio (likedHomeSection removed in 88afcd7); widget_test "crear una playlist" was flaky under the parallel suite (single 50 ms settle) -> settleUntil polling.
- 2026-10-16: The whole-branch review candidate (vs main, 109 files) stopped with lens_context_budget_exceeded, and no authority was created. The scope was reduced to f6012a7..007b9ed (9 files, 556 lines; review_due slice_budget_reached). Consent granted, 1 lens review-reliability, APPROVED and acknowledged (lineage review-1311a03d73bf2e4f, authority burned). The reviewed boundary advances to 007b9ed. New follow-ups: F11 and F12 (suggestions).

### Phase 4 — Strict use cases (user decision 2026-10-17: STRICT rule)
Rule: every presentation-triggered action/read goes through a use case (domain) that depends only on interfaces and returns `Result`. Inventory: 57 actions/reads, 1 fully via use case today. Collaborators without interface: PlaylistCoverService, YoutubePlaylistImporter, DownloadManager, LikedPlaylist, LyricsRepository, SettingsDao, HistoryDao, SearchHistoryDao, RadioService, HistoryRecorder, SleepTimerClock.
- [x] P4.1 Composition root: one DI file outside core/features (DAO, repo, service, use case providers); remove core→features imports and the playlists_providers↔repository_providers cycle; single LikedPlaylist instance shared by bootstrap and providers
- [x] P4.2 Playlists (12) + favorites (2) + downloads (7): domain interfaces for cover service, importer, liked-playlist sync, download service; one use case per action (incl. RemoveSongAt, MoveSong, ToggleLike orchestration moved out of SongActions); importer/cover/export errors as Result
- [x] P4.3 Player/queue (15) + sleep timer (4): use cases over AudioPlayerService wrapped in Result; index/mode computations out of widgets
- [x] P4.4 Search + search history + suggestions (8), history (3), settings (4), lyrics (1), export (1), radio: repository interfaces + Result; remove HistoryDao/SearchHistoryDao/SettingsDao StreamControllers; notifiers
- [ ] P4.5 SongActions dissolved into use cases; widgets call notifiers/use cases only
- 2026-10-17: Merged test branch (70eef7d), suite +325. P4.1 done (delegated writer): lib/di/{data_providers,service_providers,use_case_providers,app_overrides,providers}.dart; PlaylistDao moved to lib/core/database; core no longer imports features; player providers moved to features/player/presentation; bootstrap-owned instances (repos, LikedPlaylist, audio, DownloadManager, cover service) injected via appOverrides — single LikedPlaylist; test helper likedPlaylistFromRepositories; new test/di/app_overrides_test.dart. Parent re-ran full suite: +326. analyze 31.
- 2026-10-17: P4.2 done (delegated writer): 22 use cases for playlists/favorites/downloads (all with callers; ToggleFavorite merged into ToggleLike, RemoveSongFromPlaylist replaced by RemoveSongAt, RestoreSongAt for undo); domain interfaces IDownloadService, ILikedPlaylistSync, IPlaylistCoverService, IPlaylistImporter; Failure subtypes ValidationFailure, SyncFailure, NetworkFailure, StorageFailure; importer/cover errors as Result; F5 via LikedPlaylistSyncFailure(updatedSong); songKey helper; downloadManagerProvider renamed downloadServiceProvider. Parent re-ran full suite. Pending for P4.3/P4.5: SongActions._persist still calls songRepositoryProvider; download Result ignored by callers.
- 2026-10-17: P4.1+P4.2 review candidate (base 70eef7d, 3036 lines): consent declined by user. Medium off-path: writer self-verification + parent full-suite re-run (+371).
- 2026-10-17: P4.3 done (interrupted writer resumed by a second writer reusing its RED tests). 18 player use cases in features/player/domain/usecases (PlayQueue/PlayShuffled/PlayNext/AddToQueue persist first; transport, queue, PausePlayback, SetStopAfterCurrent, WatchPlayerSnapshot/Position); player_rules.dart (nextRepeatMode, previousSongIndex); PlaybackFailure; QueueSheet SnackBars on Err; SleepTimerController keeps UI state, calls use cases. RED compile failure -> GREEN +41. Parent re-ran full suite. No presentation access to audio/repository/download providers outside lib/di.
- 2026-10-17: P4.4 done (delegated writer): ISettingsRepository (core/domain), IHistoryRepository + HistoryEvents refresh bridge, ISearchHistoryRepository + search/suggestion interfaces in search/domain, ILyricsRepository + pure Lyrics domain, ISongExporter + ExportFailure, RadioService on interfaces with RelatedSongsFetcher; 17 new use cases; SettingsNotifier, Top/RecentSongsNotifier, RecentSearchesNotifier; History/SearchHistory/Settings DAOs pure CRUD. test/history_dao_test.dart: only the changes-assertion hunk committed (user reflow left unstaged). RED compile -> GREEN; parent re-ran full suite.
- 2026-10-17: P4.4 review: whole commit exceeded lens budget; split attempt: settings-only slice was correctly flagged CRITICAL by reviewer (does not compile alone; DI/fakes live in shared files). User chose to skip the split and continue with P4.5; P4.4 stays one commit, unreviewed. Open stale lineage review-9cff85c6850b8f95 (correction_required) left untouched — abandoning needs maintainer authorization.
