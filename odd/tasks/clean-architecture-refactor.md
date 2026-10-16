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

### Phase 2 — Data layer (pending user go-ahead)
- [ ] P2.1 `SongModel`/`PlaylistModel` DTOs + mappers to/from domain
- [ ] P2.2 Remove `StreamController` from `SongDao`/`PlaylistDao` (CRUD only); note: current `changes` consumers must be bridged until Phase 3
- [ ] P2.3 `SongRepositoryImpl`/`PlaylistRepositoryImpl` returning `Result`

### Phase 3 — Presentation (pending user go-ahead)
- [ ] P3.1 Notifiers for playlists, playlist detail, favorites, downloads
- [ ] P3.2 Refactor `PlaylistDetailScreen` and `DownloadsScreen` to notifiers
- [ ] P3.3 Error states rendered from `Result`

## Acceptance criteria (Phase 1)
- Domain files import nothing from Flutter, sqflite or data layers (only `dart:` libraries; `meta`/`collection` are not direct deps).
- Use cases depend only on repository interfaces and are covered by unit tests.
- `flutter analyze` clean on new files; `flutter test test/domain` green.

## Progress
- 2026-10-16: branch created, Phase 1 started.
- 2026-10-16: Phase 1 done (delegated writer). RED: usecases_test failed to compile before use cases existed. GREEN: `flutter test test/domain` +33 passed (parent re-ran). `flutter analyze` scoped: no issues; whole project 31 issues = baseline. Flutter SDK at C:devlutter (not on PATH); package name `sponify`.
