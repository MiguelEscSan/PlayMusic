import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/data/repositories/settings_repository_impl.dart';
import 'package:sponify/core/data/repositories/song_repository_impl.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/features/radio/domain/radio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_feature_repositories.dart';
import 'domain/fakes/fake_song_repository.dart';

Song _song(String id, {SongSource source = SongSource.youtube}) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: source,
  sourceId: id,
);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songs;
  late SettingsDao settings;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    settings = SettingsDao(db);
  });

  tearDown(() => db.close());

  RadioService radio(Future<List<Song>> Function(Song seed) fetch) =>
      RadioService(
        fetchRelated: fetch,
        songRepository: SongRepositoryImpl(songs),
        settings: SettingsRepositoryImpl(settings),
      );

  Future<List<Song>> queueOf(List<String> ids) async => [
    for (final id in ids)
      (await songs.upsert(SongModel.fromEntity(_song(id)))).toEntity(),
  ];

  test('devuelve las relacionadas guardadas en la BD con id', () async {
    Song? seed;
    final service = radio((s) async {
      seed = s;
      return [_song('r1'), _song('r2')];
    });

    final next = await service.nextFor(await queueOf(['a', 'b']));

    expect(seed?.sourceId, 'b', reason: 'semilla = última de la cola');
    expect([for (final s in next) s.sourceId], ['r1', 'r2']);
    expect(next.every((s) => s.id.isNotEmpty), isTrue);
    expect(await songs.findBySource(SongSource.youtube, 'r1'), isNotNull);
  });

  test('excluye las que ya están en la cola', () async {
    final service = radio((_) async => [_song('a'), _song('r1'), _song('b')]);
    final next = await service.nextFor(await queueOf(['a', 'b']));
    expect([for (final s in next) s.sourceId], ['r1']);
  });

  test('como máximo 10 canciones', () async {
    final service = radio(
      (_) async => [for (var i = 0; i < 25; i++) _song('r$i')],
    );
    final next = await service.nextFor(await queueOf(['a']));
    expect(next, hasLength(10));
    expect(next.first.sourceId, 'r0');
  });

  test('con la radio desactivada devuelve vacío', () async {
    await settings.setBool(SettingsKeys.radioEnabled, false);
    var called = false;
    final service = radio((_) async {
      called = true;
      return [_song('r1')];
    });
    expect(await service.nextFor(await queueOf(['a'])), isEmpty);
    expect(called, isFalse);
  });

  test('si falla al guardar (Err) devuelve vacío sin lanzar', () async {
    final service = RadioService(
      fetchRelated: (_) async => [_song('r1')],
      songRepository: FakeSongRepository(),
      settings: SettingsRepositoryImpl(settings),
    );
    expect(await service.nextFor(await queueOf(['a'])), isEmpty);
  });

  test('si no se puede leer el ajuste (Err) devuelve vacío', () async {
    var called = false;
    final service = RadioService(
      fetchRelated: (_) async {
        called = true;
        return [_song('r1')];
      },
      songRepository: SongRepositoryImpl(songs),
      settings: FakeSettingsRepository()
        ..failure = const DatabaseFailure('disk full'),
    );
    expect(await service.nextFor(await queueOf(['a'])), isEmpty);
    expect(called, isFalse);
  });

  test('si falla la búsqueda devuelve vacío', () async {
    final service = radio((_) async => throw Exception('sin red'));
    expect(await service.nextFor(await queueOf(['a'])), isEmpty);
  });

  test('semilla que no es de YouTube o cola vacía devuelve vacío', () async {
    final service = radio((_) async => [_song('r1')]);
    final local = (await songs.upsert(
      SongModel.fromEntity(_song('x', source: SongSource.local)),
    )).toEntity();
    expect(await service.nextFor([local]), isEmpty);
    expect(await service.nextFor(const []), isEmpty);
  });

  test('forSeed ordena por gustos y salta las recientes', () async {
    Song by(String id, String artist) => Song(
      id: '',
      title: 'T$id',
      artist: artist,
      durationMs: 1000,
      source: SongSource.youtube,
      sourceId: id,
    );
    for (final id in ['l1', 'l2', 'l3']) {
      final liked = (await songs.upsert(SongModel.fromEntity(by(id, 'Fav'))))
          .toEntity();
      await songs.setLiked(liked.id, true);
    }
    final service = RadioService(
      fetchRelated: (_) async => [
        by('x', 'Otro'),
        by('old', 'Otro2'),
        by('f', 'Fav'),
      ],
      songRepository: SongRepositoryImpl(songs),
      settings: SettingsRepositoryImpl(settings),
      history: FakeHistoryRepository(recent: [by('old', 'Otro2')]),
    );
    final seed = (await queueOf(['s'])).single;

    final next = await service.forSeed(seed);

    expect([for (final s in next) s.sourceId], ['f', 'x']);
  });

  test('si falla el historial, la radio sigue', () async {
    final service = RadioService(
      fetchRelated: (_) async => [_song('r1')],
      songRepository: SongRepositoryImpl(songs),
      settings: SettingsRepositoryImpl(settings),
      history: FakeHistoryRepository()
        ..failure = const DatabaseFailure('disk full'),
    );
    final next = await service.forSeed((await queueOf(['s'])).single);
    expect([for (final s in next) s.sourceId], ['r1']);
  });
}
