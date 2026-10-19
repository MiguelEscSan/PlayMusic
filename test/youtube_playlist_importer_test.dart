import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/data/repositories/playlist_repository_impl.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_playlist_repository.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/database/playlist_dao.dart';
import 'package:koda/features/playlists/data/youtube_playlist_importer.dart';
import 'package:koda/features/playlists/domain/i_playlist_importer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_playlist_repository.dart';
import 'domain/fakes/fake_remote_playlist_source.dart';

YoutubePlaylistImporter _importer(
  IPlaylistRepository playlists,
  Future<(String, List<Song?>)> Function(String id) fetch,
) => YoutubePlaylistImporter(playlists, FakeRemotePlaylistSource(fetch));

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

const _url =
    'https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H';
const _id = 'PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H';

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late PlaylistDao dao;
  late PlaylistRepositoryImpl repo;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = PlaylistDao(db, SongDao(db));
    repo = PlaylistRepositoryImpl(dao);
  });

  tearDown(() => db.close());

  List<String> titles(List<Song> s) => [for (final x in s) x.title];

  test('importa la playlist con su título y las canciones en orden', () async {
    String? requested;
    final importer = _importer(repo, (id) async {
      requested = id;
      return ('Mi mix', [_song('1'), _song('2'), _song('3')]);
    });

    final result = _ok(await importer.importFromUrl(_url));

    expect(requested, _id);
    expect(result.imported, 3);
    expect(result.skipped, 0);
    final p = _ok(await repo.findById(result.playlistId));
    expect(p.name, 'Mi mix');
    expect(titles(p.songs), ['T1', 'T2', 'T3']);
  });

  test('un enlace no válido da error y no crea playlist', () async {
    var fetched = false;
    final importer = _importer(repo, (_) async {
      fetched = true;
      return ('X', [_song('1')]);
    });

    final result = await importer.importFromUrl('https://example.com/nada');

    expect(result.failureOrNull, isA<InvalidPlaylistLinkFailure>());
    expect(fetched, isFalse);
    expect(await dao.all(), isEmpty);
  });

  test('las canciones repetidas y no disponibles se omiten', () async {
    final importer = _importer(
      repo,
      (_) async => ('Mix', [_song('1'), null, _song('2'), _song('1')]),
    );

    final result = _ok(await importer.importFromUrl(_id));

    expect(result.imported, 2);
    expect(result.skipped, 2);
    final p = _ok(await repo.findById(result.playlistId));
    expect(titles(p.songs), ['T1', 'T2']);
  });

  test('avisa del progreso tras cada canción', () async {
    final importer = _importer(
      repo,
      (_) async => ('Mix', [_song('1'), _song('2')]),
    );
    final calls = <(int, int)>[];

    await importer.importFromUrl(
      _url,
      onProgress: (done, total) => calls.add((done, total)),
    );

    expect(calls, [(0, 2), (1, 2), (2, 2)]);
  });

  test('importa como mucho 500 canciones', () async {
    final importer = _importer(
      repo,
      (_) async => ('Larga', [for (var i = 0; i < 510; i++) _song('$i')]),
    );

    final result = _ok(await importer.importFromUrl(_url));

    expect(result.imported, YoutubePlaylistImporter.maxSongs);
  });

  test('sin canciones importables da error y no crea playlist', () async {
    final importer = _importer(repo, (_) async => ('Vacía', <Song?>[null]));

    final result = await importer.importFromUrl(_url);

    expect(result.failureOrNull, isA<EmptyPlaylistFailure>());
    expect(await dao.all(), isEmpty);
  });

  test('un fallo del repositorio llega como Err, sin lanzar', () async {
    final importer = _importer(
      FakePlaylistRepository(),
      (_) async => ('Mix', [_song('1')]),
    );

    final result = await importer.importFromUrl(_url);

    expect(result.isErr, isTrue);
  });

  test('un error al leer la playlist remota es Err(NetworkFailure)', () async {
    final importer = _importer(
      repo,
      (_) async => throw Exception('sin conexión'),
    );

    final result = await importer.importFromUrl(_url);

    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(await dao.all(), isEmpty);
  });
}
