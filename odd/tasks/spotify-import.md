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
- [x] S5 UI: import dialog picks importer by link; partial-import message;
      di wiring
- [x] S6 Live check against playlist 3IH9vnqULmvIUyXAzlL9zl (122 tracks)

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
- S4 commit: 81fb852.
- S5 (inline in writer): import dialog accepts YouTube or Spotify links (`PlaylistsNotifier.importFromLink` -> `ImportPlaylistFromLinkUseCase`); `importFromYoutube` kept unchanged. Spotify-specific error texts (invalid link, not found/not public, no match); partial imports show `importSummary` in a dialog ("Importadas X de Y ... Spotify solo deja leer las N primeras ..."), otherwise the usual snack. Providers `spotifyPlaylistImporterProvider` and `importPlaylistFromLinkUseCaseProvider` live in `lib/di/service_providers.dart` (deviation: `use_case_providers.dart` was outside the allowed edit surface). RED: compile failure; GREEN: `flutter test test/spotify test/playlists` 99 passed; `dart analyze lib test/spotify` clean.
- S5 commit: 24faeab.
- S6 (inline in writer): live test `test/live/spotify_import_live_test.dart` (skipped unless `KODA_LIVE=1`; `KODA_LIVE_TRACKS=N` limits the tracks; 10 min overall timeout; per-request dio timeouts; 30 s per track search in the importer).
  - First live run with youtube_explode HTML search: 18-20 of 100 matched; YouTube answered every search after ~20 with a `google_abuse` redirect loop. Fix 26c8460: the matcher now searches through InnerTube (`youtubei/v1/search`, videos filter) with one retry; also rejects "piano" and "sessions" variants. Fixture `innertube_search.json` trimmed from a real response.
  - Coordinator asked for timeouts and a 20-track run first: 8d97226 adds `matchTimeout` (30 s, hung search -> track skipped; test with a never-completing matcher, RED then GREEN).
  - `KODA_LIVE=1 KODA_LIVE_TRACKS=20 flutter test test/live`: 20 searched, 19 imported, 1 skipped, 3 s.
  - `KODA_LIVE=1 flutter test test/live`: 100 fetched, totalCount 122, 98 imported, 2 skipped ("Cigarettes After Sex - Sweet" and "Ramma - PUTAS": YouTube returns zero results for those queries), 13 s; summary "Importadas 98 de 122 (2 omitidas). Spotify solo deja leer las 100 primeras ...".
  - Doubtful picks: "Ramma - INMORTAL" 1:37 -> official video 2:02; "Sean Kingston - Beautiful Girls" 3:45 -> lyrics upload 4:02; "Quevedo - CUÉNTALE" 3:18 -> album upload 3:31; lyric/fan-channel uploads for some tracks.
  - No Android emulator running (`flutter devices`: only Windows/Chrome/Edge): in-app import not tried.
- Final checks: `flutter test` 568 passed, 1 skipped (live), 0 failed; `flutter analyze` 31 issues, same as baseline (all in `tool/`).

## Next step
Review the branch locally; push/PR is the user's decision. Possible follow-up: move the two Spotify providers from `service_providers.dart` to `use_case_providers.dart`.
