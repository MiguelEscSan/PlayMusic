// Prueba en vivo contra Spotify y YouTube reales. Solo corre con
// KODA_LIVE=1 (flutter test test/live); en la suite normal se salta.
// KODA_LIVE_TRACKS=20 limita las pistas que se buscan (por defecto, todas).
// Cada petición tiene su propio tiempo de espera (dio) y cada búsqueda un
// máximo de 30 s en el importador; la prueba entera, 10 minutos.
// ignore_for_file: avoid_print
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/playlists/data/spotify_embed_playlist_source.dart';
import 'package:sponify/features/playlists/data/spotify_playlist_importer.dart';
import 'package:sponify/features/playlists/data/track_match_scoring.dart';
import 'package:sponify/sources/youtube/youtube_track_matcher.dart';
import 'package:sponify/features/playlists/domain/i_spotify_playlist_source.dart';
import 'package:sponify/features/playlists/domain/remote_playlist.dart';
import 'package:sponify/features/playlists/presentation/import_summary.dart';
import 'package:sponify/sources/youtube/youtube_innertube.dart';

import '../domain/fakes/fake_playlist_repository.dart';

const _playlist =
    'https://open.spotify.com/playlist/3IH9vnqULmvIUyXAzlL9zl'
    '?si=ldGskkVKRIKNydPEYSkMBA&utm_source=copy-link&pi=5XDsOpGYQwSnk';

String _mmss(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Devuelve la playlist ya leída, recortada, sin volver a pedirla.
class _FixedSource implements ISpotifyPlaylistSource {
  _FixedSource(this.playlist);

  final RemotePlaylist playlist;

  @override
  Future<Result<RemotePlaylist>> fetch(String playlistId) async => Ok(playlist);
}

void main() {
  final live = Platform.environment['KODA_LIVE'] == '1';
  final limit = int.tryParse(Platform.environment['KODA_LIVE_TRACKS'] ?? '');

  test(
    'importa "15 Marzo" con los adaptadores reales',
    () async {
      final source = SpotifyEmbedPlaylistSource.create();

      // Lectura de Spotify sola, para informar.
      final remote = switch (await source.fetch('3IH9vnqULmvIUyXAzlL9zl')) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Spotify: $failure'),
      };
      print(
        'Spotify: "${remote.name}", leídas ${remote.tracks.length}, '
        'totalCount ${remote.totalCount}',
      );
      final tracks = remote.tracks.take(limit ?? remote.tracks.length).toList();
      print('Se buscan ${tracks.length} pistas');

      // Se guardan los candidatos de cada búsqueda para explicar después
      // qué eligió el emparejador.
      final real = YoutubeTrackMatcher.innertubeCandidateSearch(
        YoutubeInnertube(),
      );
      final recorded = <String, List<MatchCandidate>>{};
      final errors = <String, String>{};
      final repo = FakePlaylistRepository()
        ..createResult = Ok(
          Playlist(
            id: 'live',
            name: remote.name,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      final importer = SpotifyPlaylistImporter(
        repo,
        _FixedSource(
          RemotePlaylist(
            name: remote.name,
            tracks: tracks,
            totalCount: remote.totalCount,
          ),
        ),
        YoutubeTrackMatcher((q) async {
          try {
            return recorded[q] = await real(q);
          } catch (e) {
            errors[q] = '$e'.split('\n').first;
            rethrow;
          }
        }),
      );

      final sw = Stopwatch()..start();
      final result = switch (await importer.importFromUrl(_playlist)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Importación: $failure'),
      };
      print(
        'Importación en ${sw.elapsed.inSeconds} s: '
        'importadas ${result.imported}, omitidas ${result.skipped}, '
        'remoteTotal ${result.remoteTotal}',
      );
      print('Mensaje: ${importSummary(result)}');

      final rows = <(double?, String)>[];
      for (final RemoteTrack t in tracks) {
        final candidates = recorded[matchQuery(t)] ?? const [];
        final best = pickBestMatch(t, candidates);
        final spotify =
            '${t.artists.join(', ')} - ${t.title} (${_mmss(t.duration)})';
        if (best == null) {
          rows.add((
            null,
            'OMITIDA  $spotify  [${errors[matchQuery(t)] ?? '${candidates.length} candidatos'}]',
          ));
          continue;
        }
        final score = scoreCandidate(t, best)!;
        rows.add((
          score,
          '${score.toStringAsFixed(2)}  $spotify  →  "${best.title}" / '
              '${best.channel} / ${_mmss(best.duration!)}',
        ));
      }
      print('--- Todas (puntuación  Spotify → YouTube) ---');
      for (final (_, line) in rows) {
        print(line);
      }

      expect(remote.tracks, hasLength(100));
      expect(remote.totalCount, 122);
      expect(result.isPartial, isTrue);
      expect(result.imported, greaterThan(tracks.length * 0.8));
    },
    skip: live ? false : 'Prueba en vivo: KODA_LIVE=1 para correrla',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
