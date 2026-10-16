import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/features/playlists/data/playlist_cover_service.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_playlist_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late PlaylistDao dao;
  late Directory tmp;
  late Directory coversDir;
  late PlaylistCoverService covers;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = PlaylistDao(db, SongDao(db));
    tmp = await Directory.systemTemp.createTemp('sponify_covers');
    coversDir = Directory(p.join(tmp.path, 'covers'));
    covers = PlaylistCoverService(PlaylistRepositoryImpl(dao), coversDir);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<String> picked(String name, String content) async {
    final file = File(p.join(tmp.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  test('copia la imagen elegida a la carpeta de portadas', () async {
    final playlist = await dao.create('Mix');
    final source = await picked('photo.jpg', 'one');

    await covers.setFromFile(playlist.id, source);

    final saved = (await dao.findById(playlist.id))!.coverUrl!;
    expect(p.isWithin(coversDir.path, saved), isTrue);
    expect(p.extension(saved), '.jpg');
    expect(await File(saved).readAsString(), 'one');
    expect(File(source).existsSync(), isTrue, reason: 'no toca el original');
  });

  test('cambiar la portada borra el archivo anterior', () async {
    final playlist = await dao.create('Mix');
    await covers.setFromFile(playlist.id, await picked('a.png', 'one'));
    final first = (await dao.findById(playlist.id))!.coverUrl!;

    await covers.setFromFile(playlist.id, await picked('b.png', 'two'));

    final second = (await dao.findById(playlist.id))!.coverUrl!;
    expect(second, isNot(first), reason: 'ruta nueva para no reusar caché');
    expect(File(first).existsSync(), isFalse);
    expect(await File(second).readAsString(), 'two');
  });

  test('quitar la portada borra el archivo y vuelve al mosaico', () async {
    final playlist = await dao.create('Mix');
    await covers.setFromFile(playlist.id, await picked('a.jpg', 'one'));
    final saved = (await dao.findById(playlist.id))!.coverUrl!;

    await covers.clear(playlist.id);

    expect((await dao.findById(playlist.id))!.coverUrl, isNull);
    expect(File(saved).existsSync(), isFalse);
  });

  test('borrar la playlist borra también su portada', () async {
    final playlist = await dao.create('Mix');
    await covers.setFromFile(playlist.id, await picked('a.jpg', 'one'));
    final saved = (await dao.findById(playlist.id))!.coverUrl!;

    await covers.deletePlaylist(playlist.id);

    expect(await dao.findById(playlist.id), isNull);
    expect(File(saved).existsSync(), isFalse);
  });

  test('un fallo del repositorio llega como Err y no borra nada', () async {
    final failing = PlaylistCoverService(FakePlaylistRepository(), coversDir);
    final source = await picked('a.jpg', 'one');

    expect((await failing.setFromFile('p1', source)).isErr, isTrue);
    expect((await failing.clear('p1')).isErr, isTrue);
    expect((await failing.deletePlaylist('p1')).isErr, isTrue);
    expect(File(source).existsSync(), isTrue);
  });

  test('nunca borra archivos fuera de la carpeta de portadas', () async {
    final playlist = await dao.create('Mix');
    final outside = await picked('keep.jpg', 'keep');
    await dao.setCover(playlist.id, outside);

    await covers.clear(playlist.id);

    expect(File(outside).existsSync(), isTrue);
  });
}
