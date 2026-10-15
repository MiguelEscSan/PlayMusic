import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/core/settings/settings_dao.dart';
import 'package:sponify/features/radio/radio_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
      RadioService(fetchRelated: fetch, songDao: songs, settings: settings);

  Future<List<Song>> queueOf(List<String> ids) async => [
    for (final id in ids) await songs.upsert(_song(id)),
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

  test('si falla la búsqueda devuelve vacío', () async {
    final service = radio((_) async => throw Exception('sin red'));
    expect(await service.nextFor(await queueOf(['a'])), isEmpty);
  });

  test('semilla que no es de YouTube o cola vacía devuelve vacío', () async {
    final service = radio((_) async => [_song('r1')]);
    final local = await songs.upsert(_song('x', source: SongSource.local));
    expect(await service.nextFor([local]), isEmpty);
    expect(await service.nextFor(const []), isEmpty);
  });
}
