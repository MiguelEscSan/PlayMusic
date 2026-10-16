import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/repositories/playlist_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/di/repository_providers.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/core/settings/settings_providers.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/playlists/data/playlist_dao.dart';
import 'package:sponify/shared/song_actions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/fakes/fake_song_repository.dart';

Song _song(String sourceId) => Song(
  id: '',
  title: 'Canción $sourceId',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: sourceId,
);

T _ok<T>(Result<T> result) {
  expect(result, isA<Ok<T>>(), reason: 'expected Ok, got $result');
  return (result as Ok<T>).value;
}

List<String> _titles(List<Song> songs) => [for (final s in songs) s.title];

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongRepositoryImpl repo;
  late FlakySongRepository flaky;
  late ProviderContainer container;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final songDao = SongDao(db);
    repo = SongRepositoryImpl(songDao);
    flaky = FlakySongRepository(repo);
    container = ProviderContainer.test(
      overrides: [
        songRepositoryProvider.overrideWithValue(flaky),
        playlistRepositoryProvider.overrideWithValue(
          PlaylistRepositoryImpl(PlaylistDao(db, songDao)),
        ),
        settingsDaoProvider.overrideWithValue(SettingsDao(db)),
        downloadedKeysProvider.overrideWithValue(const {}),
      ],
    );
  });

  tearDown(() => db.close());

  Future<Song> addLiked(String sourceId) async {
    final saved = _ok(await repo.save(_song(sourceId)));
    _ok(await repo.setLiked(saved.id, liked: true));
    return _ok(await repo.findById(saved.id));
  }

  /// Escucha las favoritas y espera su primera carga.
  Future<List<Song>> load() {
    container.listen(likedSongsProvider, (_, _) {});
    return container.read(likedSongsProvider.future);
  }

  Future<List<Song>> reloaded() => container.read(likedSongsProvider.future);

  SongActions actions() => container.read(songActionsProvider);

  group('carga', () {
    test('Ok expone las favoritas y sus claves', () async {
      await addLiked('a');
      final b = await addLiked('b');

      expect(_titles(await load()), hasLength(2));
      expect(container.read(likedKeysProvider), {'youtube:a', 'youtube:b'});
      expect(container.read(isLikedProvider(b)), isTrue);
      expect(container.read(isLikedProvider(_song('c'))), isFalse);
    });

    test('un Err es un AsyncError con su Failure y sin reintentos', () async {
      flaky.getLikedFailures = 1;
      await expectLater(load(), throwsA(same(FlakySongRepository.failure)));
      final state = container.read(likedSongsProvider);
      expect(state.error, same(FlakySongRepository.failure));
      expect(state.isLoading, isFalse);
      expect(container.read(likedKeysProvider), isEmpty);

      await addLiked('a');
      container.invalidate(likedSongsProvider);
      expect(_titles(await reloaded()), ['Canción a']);
    });
  });

  group('puente con SongActions.toggleLike', () {
    test('marcar y desmarcar refresca las favoritas', () async {
      expect(await load(), isEmpty);

      final liked = _ok(await actions().toggleLike(_song('x')));
      expect(_titles(await reloaded()), ['Canción x']);
      expect(container.read(isLikedProvider(_song('x'))), isTrue);

      _ok(await actions().toggleLike(liked));
      expect(await reloaded(), isEmpty);
      expect(container.read(isLikedProvider(_song('x'))), isFalse);
    });

    test('un Err al marcar se devuelve y no cambia nada', () async {
      expect(await load(), isEmpty);
      final callsAfterLoad = flaky.getLikedCalls;
      flaky.setLikedFailures = 1;

      final result = await actions().toggleLike(_song('x'));

      expect(result.failureOrNull, same(FlakySongRepository.failure));
      expect(await reloaded(), isEmpty);
      expect(flaky.getLikedCalls, callsAfterLoad, reason: 'nada que recargar');
    });
  });
}
