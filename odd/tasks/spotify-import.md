# Spotify playlist import

## Objective
Import a public Spotify playlist into Koda with no login, matching each track
to a YouTube result, behind ports and adapters so a Spotify change only
touches its adapter.

## Problem
Koda imports YouTube playlists only. Spotify has no login-free official API
for other users' playlists (Feb 2026 dev-mode rules). The public embed page
returns the first 100 tracks; the public playlist page exposes the real total.

## Constraints
- No login, no web player token, no `get_access_token`/TOTP.
- Follow repo conventions: `Result`/`Failure`, use cases, di providers,
  Spanish UI text and comments, YouTube import as the model
  (`IPlaylistImporter`, `ImportResult`, progress dialog).
- Embed is capped at 100 tracks; surface "Importadas X de Y" when short.
- Retry on 5xx and timeouts (a 504 was observed).
- Local branch only, no push. No AI attribution trailers in commits.
- The working tree carries unrelated uncommitted changes from `main`:
  stage only this feature's files.

## Delivery
- Branch: `feature/spotify-import` (local). Strategy: `ask-on-risk`.

## Tasks
- [x] S1 Domain ports: `ISpotifyPlaylistSource` (plain domain playlist: name,
      tracks with title/artists/durationMs, nullable totalCount) and
      `ITrackMatcher`
- [x] S2 `SpotifyEmbedPlaylistSource` adapter (dio): `__NEXT_DATA__` parser,
      totalCount from public page via crawler User-Agent, retries; fixture tests
- [x] S3 `YouTubeTrackMatcher` adapter: scoring by duration (~10 s), title
      similarity, official/Topic channels, live filtering; scoring tests
- [x] S4 `SpotifyPlaylistImporter` implementing `IPlaylistImporter`: link
      parsing (URL with query params, `spotify:playlist:` URI, bare id),
      progress, `ImportResult` remote total; tests with fake ports
- [ ] S5 UI: import dialog picks importer by link; partial-import message;
      di wiring
- [ ] S6 Live check against playlist 3IH9vnqULmvIUyXAzlL9zl (122 tracks)

Route: delegated direct (writer trigger: 2+ non-trivial files).

## Progress
- Branch created from `main` at 3c5e31d.
- Baseline (before changes): `flutter test` 502 passed, 0 failed; `flutter analyze` 31 issues (all pre-existing).
- S1 (inline in writer): `RemoteTrack`/`RemotePlaylist`, `ISpotifyPlaylistSource`, `ITrackMatcher` in `lib/features/playlists/domain/`. No meaningful RED (types only); `flutter test test/spotify` 2 passed, `dart analyze` clean.

- S1 commit: dab496c.
- S2 (inline in writer): `spotify_page_parser.dart` (pure) + `SpotifyEmbedPlaylistSource` (dio, 3 attempts with doubling backoff on 5xx/timeouts/connection errors; 404 -> NotFoundFailure; total via crawler UA, any failure -> null). Fixtures trimmed from a real embed response (3 tracks) and a public-page meta; the `initialState` fixture is synthetic (the crawler page fetched on 2026-10-18 had no `initialState`). RED: compile failure (missing files); GREEN: `flutter test test/spotify` 17 passed; `dart analyze` clean.
- S2 commit: 2a1de15.
- S3 (inline in writer): pure `track_match_scoring.dart` (rejects live/cover/karaoke/remix/sped-up unless the Spotify title has it, duration >30 s, title coverage <0.5, no artist token; score = 0.35 title + 0.25 artist + 0.25 duration (full within 10 s) + 0.15 official/Topic/VEVO channel; accept >= 0.6) and `YoutubeTrackMatcher` (youtube_explode search, top 10, stores Spotify title/artists on the Song). RED: compile failure; GREEN: `flutter test test/spotify` 35 passed; `dart analyze` clean.
- S3 commit: dfaed5c.
- S4 (inline in writer): `parseSpotifyPlaylistId`/`isSpotifyLink` (domain), `SpotifyPlaylistImporter` (matches all tracks first, 4 at a time, order kept, progress per match; creates the playlist only if something matched), `ImportResult.remoteTotal` + `read`/`isPartial`, `InvalidPlaylistLinkFailure` takes an optional message, `ImportPlaylistFromLinkUseCase` routes Spotify-looking links to Spotify and everything else to YouTube. Fakes `FakeSpotifyPlaylistSource`/`FakeTrackMatcher`. RED: compile failure; GREEN: `flutter test test/spotify test/domain test/youtube_playlist_importer_test.dart` 218 passed; `dart analyze` clean.

## Next step
S5.
