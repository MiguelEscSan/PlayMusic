# Music source ports and adapters

Search, audio, radio and remote playlist reading go through domain ports.
YouTube is one adapter. No behaviour change.

## Ports (`lib/core/domain/sources/`)

| Port | Role |
| --- | --- |
| `SourceAdapter` | An adapter declares the `SongSource` it serves. |
| `SourceRegistry<T>` | Picks the adapter for `Song.source`; `null` when none. |
| `IStreamResolver` | Fresh playable URL for a song (was `StreamUrlProvider`). |
| `ITrackSearch` | Search songs by text (was `SearchSource`). |
| `IRadioSource` | Mix / related songs for a seed song. |
| `IRemotePlaylistSource` | Parse a link and read a remote playlist as songs. |

Kept where they were: `SuggestionSource`, `ITrackMatcher`,
`ISpotifyPlaylistSource`, `IPlaylistImporter`, `PlaybackSourceResolver`.

## YouTube adapter (`lib/sources/youtube/`)

| File | Port |
| --- | --- |
| `youtube_innertube.dart` | Shared InnerTube client and JSON helpers |
| `youtube_stream_resolver.dart` | `IStreamResolver` (visionOS + `visitorData`, 2 min rate-limit wait, default-client fallback) |
| `youtube_track_search.dart` | `ITrackSearch` |
| `youtube_suggestion_source.dart` | `SuggestionSource` |
| `youtube_radio_source.dart` | `IRadioSource` (Mix parser, related songs, artist fallback) |
| `youtube_playlist_source.dart` | `IRemotePlaylistSource` (`browse VL<id>`, `lockupViewModel`) |
| `youtube_track_matcher.dart` | `ITrackMatcher` (Spotify to YouTube) |

## Routing

- `DefaultPlaybackSourceResolver` and `RadioService` take a `SourceRegistry`.
  The local file is checked before any adapter, so a downloaded song never
  touches the network.
- A song whose source has no adapter keeps the old behaviour (direct URL or
  unavailable; no radio).
- Only the composition root (`bootstrap.dart`, `lib/di/`) imports
  `lib/sources/**`. `test/architecture/source_boundary_test.dart` fails if any
  other file under `lib/` imports `youtube_explode_dart`, `sources/youtube/`
  or the old InnerTube path.

## Inventory (before)

- InnerTube client: `features/search/data`, used by search, Mixes, playlist
  import and the Spotify matcher.
- Stream provider and visionOS client: `core/audio`.
- Mix parser and `RadioService` hardcoding `SongSource.youtube`:
  `features/radio`.
- `YoutubePlaylistImporter` mixing generic import with InnerTube browse:
  `features/playlists/data`.
- `YoutubeExplode()` built in `bootstrap.dart` and `di/service_providers.dart`.

## Not separated cleanly

- `YoutubeBlockedException` / `YoutubeRateLimitedException` still live in
  `core/audio/playback_source.dart` and are caught by name in
  `koda_audio_handler.dart`. Stream resolution throws; it is not
  `Result`-based, so a `RateLimitedFailure` needs a wider change. A neutral
  rename (`SourceRateLimitedException`) is a safe follow-up.
- `core/audio/http_range_audio_source.dart` only mentions `youtube_explode`
  in a comment; it has no import.
