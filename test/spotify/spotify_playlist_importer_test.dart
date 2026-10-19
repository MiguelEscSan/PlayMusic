import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/playlist.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/playlists/data/spotify_playlist_importer.dart';
import 'package:koda/features/playlists/domain/i_playlist_importer.dart';
import 'package:koda/features/playlists/domain/remote_playlist.dart';

import '../domain/fakes/fake_playlist_repository.dart';
import '../domain/fakes/fake_services.dart';

const _id = '3IH9vnqULmvIUyXAzlL9zl';
const _link =
    'https://open.spotify.com/playlist/$_id?si=abc&utm_source=copy-link';

RemoteTrack _track(int i) =>
    RemoteTrack(title: 'T$i', artists: const ['A'], durationMs: 1000 + i);

List<RemoteTrack> _tracks(int n) => [for (var i = 0; i < n; i++) _track(i)];

void main() {
  _timeoutTests();

  late FakePlaylistRepository repo;
  late FakeSpotifyPlaylistSource source;
  late FakeTrackMatcher matcher;
  late SpotifyPlaylistImporter importer;

  setUp(() {
    repo = FakePlaylistRepository()
      ..createResult = Ok(
        Playlist(
          id: 'p1',
          name: 'Mix',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
    source = FakeSpotifyPlaylistSource();
    matcher = FakeTrackMatcher();
    importer = SpotifyPlaylistImporter(repo, source, matcher);
  });

  ImportResult ok(Result<ImportResult> r) {
    expect(r, isA<Ok<ImportResult>>(), reason: '$r');
    return (r as Ok<ImportResult>).value;
  }

  test('crea la playlist con su nombre y las canciones en orden', () async {
    source.result = Ok(RemotePlaylist(name: '15 Marzo', tracks: _tracks(3)));
    final progress = <(int, int)>[];

    final result = ok(
      await importer.importFromUrl(
        _link,
        onProgress: (done, total) => progress.add((done, total)),
      ),
    );

    expect(source.calls, [_id]);
    expect(repo.createCalls, ['15 Marzo']);
    expect(repo.addSongCalls.map((c) => c.song.title), ['T0', 'T1', 'T2']);
    expect(repo.addSongCalls.map((c) => c.playlistId).toSet(), {'p1'});
    expect(result.playlistId, 'p1');
    expect(result.imported, 3);
    expect(result.skipped, 0);
    expect(result.remoteTotal, isNull);
    expect(result.isPartial, isFalse);
    expect(progress.first, (0, 3));
    expect(progress.last, (3, 3));
    expect(progress, hasLength(4));
  });

  test('mantiene el orden aunque las búsquedas acaben desordenadas', () async {
    source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(8)));
    matcher.answer = (t) async {
      final i = int.parse(t.title.substring(1));
      await Future<void>.delayed(Duration(milliseconds: (8 - i) * 3));
      return Ok(
        Song(
          id: '',
          title: t.title,
          artist: 'A',
          durationMs: 1,
          source: SongSource.youtube,
          sourceId: t.title,
        ),
      );
    };

    ok(await importer.importFromUrl(_id));

    expect(repo.addSongCalls.map((c) => c.song.title), [
      for (var i = 0; i < 8; i++) 'T$i',
    ]);
  });

  test('100 de 122: avisa del total remoto', () async {
    source.result = Ok(
      RemotePlaylist(name: 'Mix', tracks: _tracks(100), totalCount: 122),
    );

    final result = ok(await importer.importFromUrl(_link));

    expect(result.imported, 100);
    expect(result.skipped, 0);
    expect(result.remoteTotal, 122);
    expect(result.read, 100);
    expect(result.isPartial, isTrue);
  });

  test('un total igual a lo leído no es parcial', () async {
    source.result = Ok(
      RemotePlaylist(name: 'Mix', tracks: _tracks(3), totalCount: 3),
    );
    expect(ok(await importer.importFromUrl(_id)).isPartial, isFalse);
  });

  test(
    'omite pistas sin coincidencia, con fallo de búsqueda o repetidas',
    () async {
      source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(4)));
      matcher.answer = (t) async => switch (t.title) {
        'T1' => const Ok(null),
        'T2' => const Err(NetworkFailure('sin red')),
        _ => Ok(
          Song(
            id: '',
            title: t.title,
            artist: 'A',
            durationMs: 1,
            source: SongSource.youtube,
            sourceId: t.title,
          ),
        ),
      };

      final result = ok(await importer.importFromUrl(_id));

      expect(repo.addSongCalls.map((c) => c.song.title), ['T0', 'T3']);
      expect(result.imported, 2);
      expect(result.skipped, 2);
    },
  );

  test('una canción repetida cuenta como omitida', () async {
    source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(2)));
    repo.addSongResult = const Ok(false);

    final result = ok(await importer.importFromUrl(_id));

    expect(result.imported, 0);
    expect(result.skipped, 2);
  });

  test('sin nombre, usa "Playlist de Spotify"', () async {
    source.result = Ok(RemotePlaylist(name: '  ', tracks: _tracks(1)));
    ok(await importer.importFromUrl(_id));
    expect(repo.createCalls, ['Playlist de Spotify']);
  });

  test('un enlace no válido no lee nada ni crea la playlist', () async {
    final result = await importer.importFromUrl(
      'https://open.spotify.com/album/$_id',
    );

    expect(result.failureOrNull, isA<InvalidPlaylistLinkFailure>());
    expect(source.calls, isEmpty);
    expect(repo.createCalls, isEmpty);
  });

  test('un fallo de red al leer Spotify llega tal cual', () async {
    source.result = const Err(NetworkFailure('sin red'));

    final result = await importer.importFromUrl(_id);

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(repo.createCalls, isEmpty);
    expect(matcher.calls, isEmpty);
  });

  test(
    'si todas las búsquedas fallan es NetworkFailure y no se crea nada',
    () async {
      source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(3)));
      matcher.error = Exception('sin red');

      final result = await importer.importFromUrl(_id);

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(repo.createCalls, isEmpty);
    },
  );

  test(
    'sin pistas, o sin ninguna coincidencia, es EmptyPlaylistFailure',
    () async {
      source.result = const Ok(RemotePlaylist(name: 'Mix', tracks: []));
      expect(
        (await importer.importFromUrl(_id)).failureOrNull,
        isA<EmptyPlaylistFailure>(),
      );

      source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(2)));
      matcher.answer = (_) async => const Ok(null);
      expect(
        (await importer.importFromUrl(_id)).failureOrNull,
        isA<EmptyPlaylistFailure>(),
      );
      expect(repo.createCalls, isEmpty);
    },
  );

  test('un fallo al guardar llega como su Err', () async {
    source.result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(2)));
    repo.addSongResult = const Err(DatabaseFailure('disco lleno'));

    final result = await importer.importFromUrl(_id);

    expect(result.failureOrNull, isA<DatabaseFailure>());
  });
}

void _timeoutTests() {
  test('una búsqueda colgada no bloquea la importación: se omite', () async {
    final repo = FakePlaylistRepository()
      ..createResult = Ok(
        Playlist(
          id: 'p1',
          name: 'Mix',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
    final source = FakeSpotifyPlaylistSource()
      ..result = Ok(RemotePlaylist(name: 'Mix', tracks: _tracks(3)));
    final matcher = FakeTrackMatcher();
    matcher.answer = (t) => t.title == 'T1'
        ? Completer<Result<Song?>>()
              .future // Nunca termina.
        : Future.value(
            Ok(
              Song(
                id: '',
                title: t.title,
                artist: 'A',
                durationMs: 1,
                source: SongSource.youtube,
                sourceId: t.title,
              ),
            ),
          );
    final importer = SpotifyPlaylistImporter(
      repo,
      source,
      matcher,
      matchTimeout: const Duration(milliseconds: 50),
    );

    final result = (await importer.importFromUrl(_id)).valueOrNull!;

    expect(result.imported, 2);
    expect(result.skipped, 1);
  });
}
