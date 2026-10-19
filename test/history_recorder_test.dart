import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/audio/audio_player_service.dart';
import 'package:koda/core/data/models/song_model.dart';
import 'package:koda/core/database/app_database.dart';
import 'package:koda/core/database/song_dao.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/features/history/data/history_dao.dart';
import 'package:koda/features/history/data/history_recorder.dart';
import 'package:koda/features/history/data/history_repository_impl.dart';
import 'package:koda/features/history/domain/history_events.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/fakes/fake_feature_repositories.dart';

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
  late HistoryEvents events;
  late _FakeAudio audio;
  late HistoryRecorder recorder;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    songs = SongDao(db);
    dao = HistoryDao(db);
    events = HistoryEvents();
    audio = _FakeAudio();
    recorder = HistoryRecorder(
      audio: audio,
      history: HistoryRepositoryImpl(dao),
      events: events,
    );
  });

  tearDown(() async {
    await recorder.dispose();
    await events.dispose();
    await db.close();
  });

  test('guarda cada canción que empieza a sonar y lo anuncia', () async {
    final song = (await songs.upsert(SongModel.fromEntity(_song('a'))))
        .toEntity();
    final changed = events.changes.first;
    audio.started.add(song);
    await changed;
    expect([for (final s in await dao.recent()) s.id], [song.id]);
  });

  test('ignora canciones sin id', () async {
    var announced = false;
    final sub = events.changes.listen((_) => announced = true);
    audio.started.add(_song('x'));
    await pumpEventQueue();
    expect(await dao.recent(), isEmpty);
    expect(announced, isFalse);
    await sub.cancel();
  });

  test('si no se puede guardar no lo anuncia ni lanza', () async {
    final failing = FakeHistoryRepository()
      ..failure = const DatabaseFailure('disk full');
    final other = HistoryRecorder(
      audio: audio,
      history: failing,
      events: events,
    );
    addTearDown(other.dispose);
    await recorder.dispose();

    var announced = false;
    final sub = events.changes.listen((_) => announced = true);
    audio.started.add(_song('a').copyWith(id: '1'));
    await pumpEventQueue();
    expect(announced, isFalse);
    await sub.cancel();
  });

  test('tras dispose deja de escuchar', () async {
    final song = (await songs.upsert(SongModel.fromEntity(_song('a'))))
        .toEntity();
    await recorder.dispose();
    audio.started.add(song);
    await pumpEventQueue();
    expect(await dao.recent(), isEmpty);
  });
}
