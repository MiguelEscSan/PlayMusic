# Music source behind ports and adapters

## Objective
Put Koda's music source (YouTube today) behind domain ports so that a YouTube
change, or a new source, only touches an adapter plus its registration.
Behaviour must not change.

## Current state (before)
- Ports that already exist and are kept:
  - `StreamUrlProvider` (`core/audio/stream_url_provider.dart`): per-source
    fresh URL, keyed by `SongSource`. `DefaultPlaybackSourceResolver` already
    keeps a `Map<SongSource, StreamUrlProvider>` and checks the local file
    first. It lives next to the YouTube implementation, which imports
    `youtube_explode_dart`.
  - `PlaybackSourceResolver`: local file / cached URL / fresh URL.
  - `SearchSource`, `SuggestionSource` (search domain).
  - `IPlaylistImporter`, `ISpotifyPlaylistSource`, `ITrackMatcher`
    (playlists domain).
- Leaks:
  - `RadioService` takes a `RelatedSongsFetcher` closure and hardcodes
    `seed.source != SongSource.youtube`.
  - `YoutubePlaylistImporter` mixes the generic import (create playlist, add
    songs, progress) with InnerTube `browse` calls and youtube_explode's
    `PlaylistId` parser.
  - YouTube code is spread over `core/audio`, `features/search/data`,
    `features/radio/data` and `features/playlists/data`, and the radio and
    playlist adapters import `search/data/youtube_innertube.dart`.
  - `bootstrap.dart` and `di/service_providers.dart` build `YoutubeExplode()`.

## Target
- Ports in `lib/core/domain/sources/` (pure Dart, depend on `Song` only):
  - `SourceAdapter` (an adapter knows its `SongSource`) and
    `SourceRegistry<T>`: picks the adapter for `Song.source`.
  - `IStreamResolver` (renamed from `StreamUrlProvider`): fresh playable URL.
  - `IRadioSource`: Mix / related songs for a seed.
  - `ITrackSearch` (renamed from `SearchSource`) with `SearchPage`.
  - `IRemotePlaylistSource`: parse a link and read a remote playlist as
    songs; the YouTube import uses it.
  - Kept where they are: `SuggestionSource`, `ITrackMatcher`,
    `ISpotifyPlaylistSource`, `IPlaylistImporter`, `PlaybackSourceResolver`.
- Adapters in `lib/sources/youtube/`: InnerTube client and JSON helpers,
  stream resolver (visionOS, visitorData, rate-limit, probe), search,
  suggestions, radio (Mix parser + related + artist search fallback),
  playlist browse source, track matcher.
- Routing: `DefaultPlaybackSourceResolver` and `RadioService` take a
  `SourceRegistry`. A song with no adapter keeps today's behaviour (direct
  URL or unavailable; no radio). Local files are checked before any adapter.
- Composition root only (`bootstrap.dart`, `lib/di/`) imports
  `lib/sources/**`. A test fails if anything else under `lib/` imports
  `youtube_explode_dart`, `sources/youtube/` or the old InnerTube file.

## Constraints
- No behaviour change: same strings, timeouts, retries, limits.
- Local branch `refactor/music-source-ports` from `feature/spotify-import`,
  in a separate worktree so main's uncommitted changes stay untouched.
  No push, no merge, no tag. No AI attribution trailers.
- Baseline: 568 tests passing, 1 skipped; `flutter analyze` clean.

## Tasks
- [x] P1 Ports + `SourceRegistry`, with registry tests (route: inline)
- [x] P2 Streams: YouTube stream resolver moved to `sources/youtube`,
      implements `IStreamResolver`; resolver routes through the registry;
      routing tests with fake adapters (route: inline)
- [x] P3 Search: `ITrackSearch`; InnerTube client, search and suggestions
      moved to `sources/youtube` (route: inline)
- [x] P4 Radio: `IRadioSource`; Mix/related moved; `RadioService` routes by
      seed source; tests with fake adapters (route: inline)
- [x] P5 Playlists: `IRemotePlaylistSource`; browse parser and track matcher
      moved; `YoutubePlaylistImporter` keeps only the generic import
      (route: inline)
- [x] P6 Boundary test: no YouTube imports outside the adapter folder and the
      composition root (route: inline)

Route note: all tasks inline; the parent already holds the full map of the
YouTube code, so a delegated writer would re-derive it.

## Checks per task
`flutter test` (all green, count >= baseline + new tests) and
`flutter analyze` (no issues).

## Progress
All tasks done. Commits: P1 c8c8c17, P2 55a6b9f, P3 5083119, P4 3b81cda,
P5 1e49d06, P6 71a924c (plan c438cf0).

Verification (observed): `flutter test` 581 passing, 1 skipped (baseline
568 + 13 new: 3 registry, 4 stream routing, 1 radio routing, 5 boundary);
`flutter analyze` no issues.

Not cleanly separated:
- `YoutubeBlockedException` / `YoutubeRateLimitedException` still live in
  `core/audio/playback_source.dart`, and the audio handler catches them by
  name. They mean "source blocked / rate limited", but renaming them touches
  the player and its user messages; left for a follow-up.
- `YoutubePlaylistImporter` (playlists/data) now depends only on
  `IRemotePlaylistSource`, but keeps its name and its YouTube wording in user
  messages ("Playlist de YouTube"), so the UI text does not change.
- `YoutubeTrackMatcher` (adapter) reuses the source-agnostic scoring in
  `features/playlists/data/track_match_scoring.dart`.
- Search and playlist import are not routed by `Song.source` (there is no
  song yet): DI binds the YouTube adapter directly. A second source would
  need a choice there (for example by link, as the Spotify import does).

Next step: Trepu reviews the branch locally; push and merge are their call.
