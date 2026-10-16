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
- [ ] P2.2 (moved) Remove `StreamController` from DAOs; reactivity owned by notifiers
- [ ] P3.1 Notifiers for playlists, playlist detail, favorites, downloads
- [ ] P3.2 Refactor `PlaylistDetailScreen` and `DownloadsScreen` to notifiers
- [ ] P3.3 Error states rendered from `Result`

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
