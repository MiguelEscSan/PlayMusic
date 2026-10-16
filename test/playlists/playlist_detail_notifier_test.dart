import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/di/repository_providers.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/features/playlists/presentation/playlists_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_playlist_repository.dart';

Song _song(int i) => Song(
  id: '',
  title: 'T$i',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

List<String> _titles(Playlist p) => [for (final s in p.songs) s.title];

/// Claves descargadas controlables desde el test.
class _Keys extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void set(Set<String> keys) => state = keys;
}

final _keysProvider = NotifierProvider<_Keys, Set<String>>(_Keys.new);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songDao;
  late PlaylistRepositoryImpl repo;
  late FlakyPlaylistRepository flaky;
  late ProviderContainer container;
  late String id;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songDao = SongDao(db);
    repo = PlaylistRepositoryImpl(PlaylistDao(db, songDao));
    flaky = FlakyPlaylistRepository(repo);
    container = ProviderContainer.test(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(flaky),
        downloadedKeysProvider.overrideWith((ref) => ref.watch(_keysProvider)),
      ],
    );
    id = _ok(await repo.create('Mix')).id;
    for (final i in [0, 1, 2]) {
      _ok(await repo.addSong(id, _song(i)));
    }
  });

  tearDown(() => db.close());

  /// Escucha el detalle (es autoDispose) y espera su primera carga.
  Future<Playlist> load([String? playlistId]) {
    final provider = playlistProvider(playlistId ?? id);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  PlaylistDetailNotifier notifier() =>
      container.read(playlistProvider(id).notifier);

  Playlist current() => container.read(playlistProvider(id)).requireValue;

  Future<List<String>> dbTitles() async =>
      _titles(_ok(await repo.findById(id)));

  group('carga', () {
    test('Ok expone la playlist con sus canciones', () async {
      expect(_titles(await load()), ['T0', 'T1', 'T2']);
    });

    test(
      'una playlist inexistente es un AsyncError(NotFoundFailure)',
      () async {
        await expectLater(load('nope'), throwsA(isA<NotFoundFailure>()));
        final state = container.read(playlistProvider('nope'));
        expect(state.error, isA<NotFoundFailure>());
        expect(state.isLoading, isFalse, reason: 'sin reintentos automáticos');
      },
    );

    test('un Err del repositorio es un AsyncError con su Failure', () async {
      flaky.findByIdFailures = 1;
      await expectLater(load(), throwsA(same(FlakyPlaylistRepository.failure)));
      expect(container.read(playlistProvider(id)).isLoading, isFalse);

      container.invalidate(playlistProvider(id));
      expect(_titles(await container.read(playlistProvider(id).future)), [
        'T0',
        'T1',
        'T2',
      ]);
    });
  });

  group('removeSongAt', () {
    test('Ok quita la canción del estado y de la BD', () async {
      await load();
      final result = await notifier().removeSongAt(1);

      expect(result, isA<Ok<Unit>>());
      expect(_titles(current()), ['T0', 'T2']);
      expect(await dbTitles(), ['T0', 'T2']);
    });

    test(
      'F1: aplica el cambio al instante y lo deshace si la BD falla',
      () async {
        final before = await load();
        flaky.removeSongAtFailures = 1;

        final pending = notifier().removeSongAt(0);
        expect(_titles(current()), ['T1', 'T2'], reason: 'optimista');

        final result = await pending;
        expect(result, isA<Err<Unit>>());
        expect(result.failureOrNull, same(FlakyPlaylistRepository.failure));
        expect(current(), before, reason: 'vuelve al estado anterior');
        expect(_titles(current()), ['T0', 'T1', 'T2']);
        expect(await dbTitles(), ['T0', 'T1', 'T2']);
      },
    );
  });

  group('addSong (deshacer)', () {
    test('Ok la vuelve a poner en su posición', () async {
      await load();
      final removed = current().songs[0];
      _ok(await notifier().removeSongAt(0));

      final result = await notifier().addSong(removed, at: 0);

      expect(_ok(result), isTrue);
      expect(_titles(current()), ['T0', 'T1', 'T2']);
      expect(await dbTitles(), ['T0', 'T1', 'T2']);
    });

    test('sin posición la añade al final', () async {
      await load();
      _ok(await notifier().addSong(_song(3)));
      expect(_titles(current()), ['T0', 'T1', 'T2', 'T3']);
      expect(await dbTitles(), ['T0', 'T1', 'T2', 'T3']);
    });

    test('Err deshace la inserción optimista y devuelve el Err', () async {
      await load();
      final removed = current().songs[1];
      _ok(await notifier().removeSongAt(1));
      flaky.addSongFailures = 1;

      final pending = notifier().addSong(removed, at: 1);
      expect(_titles(current()), ['T0', 'T1', 'T2'], reason: 'optimista');

      final result = await pending;
      expect(result.isErr, isTrue);
      // Se relee de la BD (no se restaura una copia).
      expect(current(), _ok(await repo.findById(id)));
      expect(_titles(current()), ['T0', 'T2']);
    });

    test('si falla la recolocación se resincroniza con la BD', () async {
      await load();
      final removed = current().songs[0];
      _ok(await notifier().removeSongAt(0));
      flaky.moveSongFailures = 1;

      final result = await notifier().addSong(removed, at: 0);

      expect(result.isErr, isTrue);
      // La BD la añadió al final; el estado refleja la BD, no la posición
      // optimista.
      expect(await dbTitles(), ['T1', 'T2', 'T0']);
      expect(_titles(await container.read(playlistProvider(id).future)), [
        'T1',
        'T2',
        'T0',
      ]);
    });
  });

  group('move', () {
    test('Ok reordena estado y BD', () async {
      await load();
      _ok(await notifier().move(0, 2));
      expect(_titles(current()), ['T1', 'T2', 'T0']);
      expect(await dbTitles(), ['T1', 'T2', 'T0']);
    });

    test('Err vuelve al orden anterior', () async {
      final before = await load();
      flaky.moveSongFailures = 1;
      final result = await notifier().move(0, 2);
      expect(result.isErr, isTrue);
      expect(current(), before);
    });
  });

  group('rename', () {
    test('Ok renombra el detalle y la lista', () async {
      await load();
      container.listen(playlistsProvider, (_, _) {});
      await container.read(playlistsProvider.future);

      _ok(await notifier().rename('Nuevo'));

      expect((await container.read(playlistProvider(id).future)).name, 'Nuevo');
      final list = await container.read(playlistsProvider.future);
      expect(list.single.name, 'Nuevo');
    });

    test('Err se devuelve y no cambia nada', () async {
      await load();
      flaky.renameFailures = 1;
      final result = await notifier().rename('Nuevo');
      expect(result.isErr, isTrue);
      expect(current().name, 'Mix');
    });
  });

  test('una mutación del detalle refresca playlistsProvider', () async {
    await load();
    container.listen(playlistsProvider, (_, _) {});
    expect((await container.read(playlistsProvider.future)).single.length, 3);

    _ok(await notifier().removeSongAt(0));

    expect((await container.read(playlistsProvider.future)).single.length, 2);
  });

  group('F6: mutaciones solapadas', () {
    test('la primera falla después de que la segunda guarde: '
        'el estado final es el de la BD', () async {
      await load();
      final gate = Completer<void>();
      flaky
        ..removeSongAtFailures = 1
        ..removeSongAtGate = gate;

      final first = notifier().removeSongAt(1); // T1, fallará
      final second = notifier().removeSongAt(0); // T0, se guarda
      _ok(await second);
      gate.complete();
      expect((await first).isErr, isTrue);

      expect(await dbTitles(), ['T1', 'T2']);
      expect(_titles(current()), await dbTitles());
    });

    test('la primera falla antes de que la segunda guarde: '
        'el estado final es el de la BD', () async {
      await load();
      final gate = Completer<void>();
      flaky.removeSongAtFailures = 1;

      final first = notifier().removeSongAt(0); // T0, falla al instante
      flaky.removeSongAtGate = gate;
      final second = notifier().removeSongAt(0); // T1 en el estado optimista
      expect((await first).isErr, isTrue);
      gate.complete();
      _ok(await second);

      // La BD quitó la primera fila que tenía (T0).
      expect(await dbTitles(), ['T1', 'T2']);
      expect(_titles(current()), await dbTitles());
    });
  });

  group('F7: recarga por descargas con una escritura pendiente', () {
    test('la recarga termina antes que la escritura', () async {
      await load();
      final gate = Completer<void>();
      flaky.removeSongAtGate = gate;

      final pending = notifier().removeSongAt(0);
      container.read(_keysProvider.notifier).set({'youtube:yt9'});
      // La recarga lee la BD antes de que se guarde el cambio.
      expect(_titles(await container.read(playlistProvider(id).future)), [
        'T0',
        'T1',
        'T2',
      ]);
      gate.complete();
      _ok(await pending);

      expect(await dbTitles(), ['T1', 'T2']);
      expect(_titles(current()), await dbTitles());
    });

    test('la escritura empieza con una recarga en curso', () async {
      await load();
      container.read(_keysProvider.notifier).set({'youtube:yt9'});
      // Arranca la recarga (lee la BD) sin esperarla.
      expect(container.read(playlistProvider(id)).isLoading, isTrue);

      _ok(await notifier().removeSongAt(0));
      await container.read(playlistProvider(id).future);

      expect(await dbTitles(), ['T1', 'T2']);
      expect(_titles(current()), await dbTitles());
    });
  });

  test('se refresca cuando cambian las canciones descargadas', () async {
    final loaded = await load();
    expect(loaded.downloadedCount, 0);

    final song = loaded.songs[1];
    _ok(
      await SongRepositoryImpl(songDao)
          .markDownloaded(song.id, localPath: '/music/t1.m4a', sizeBytes: 1),
    );
    container.read(_keysProvider.notifier).set({'youtube:yt1'});

    final refreshed = await container.read(playlistProvider(id).future);
    expect(refreshed.downloadedCount, 1);
    expect(refreshed.songs[1].isDownloaded, isTrue);
  });
}
