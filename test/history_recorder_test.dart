import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/database/app_database.dart';
import 'package:sponify/core/database/song_dao.dart';
import 'package:sponify/core/models/song.dart';
import 'package:sponify/features/history/data/history_dao.dart';
import 'package:sponify/features/history/data/history_recorder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reproductor falso: solo expone [songStarted].
class _FakeAudio implements AudioPlayerService {
  final started = StreamController<Song>.broadcast();

  @override
  Stream<Song> get songStarted => started.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Song _song(String id) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SongDao songs;
  late HistoryDao dao;
  late _FakeAudio audio;
  late HistoryRecorder recorder;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    dao = HistoryDao(db);
    audio = _FakeAudio();
    recorder = HistoryRecorder(audio: audio, dao: dao);
  });

  tearDown(() async {
    await recorder.dispose();
    await db.close();
  });

  test('guarda cada canción que empieza a sonar', () async {
    final song = await songs.upsert(_song('a'));
    final changed = dao.changes.first;
    audio.started.add(song);
    await changed;
    expect([for (final s in await dao.recent()) s.id], [song.id]);
  });

  test('ignora canciones sin id', () async {
    audio.started.add(_song('x'));
    await pumpEventQueue();
    expect(await dao.recent(), isEmpty);
  });

  test('tras dispose deja de escuchar', () async {
    final song = await songs.upsert(_song('a'));
    await recorder.dispose();
    audio.started.add(song);
    await pumpEventQueue();
    expect(await dao.recent(), isEmpty);
  });
}
