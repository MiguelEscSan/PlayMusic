import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/di/providers.dart';
import 'package:sponify/features/history/data/history_recorder.dart';
import 'package:sponify/features/history/presentation/history_providers.dart';

import '../domain/fakes/fake_feature_repositories.dart';

Song _song(String id) => Song(
  id: id,
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

/// Reproductor falso: solo expone [songStarted].
class _FakeAudio implements AudioPlayerService {
  final started = StreamController<Song>.broadcast();

  @override
  Stream<Song> get songStarted => started.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late FakeHistoryRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeHistoryRepository(recent: [_song('a')], top: [_song('a')]);
    container = ProviderContainer(
      overrides: [historyRepositoryProvider.overrideWithValue(repo)],
    );
    // Mantiene vivos los providers, como haría la pantalla de Inicio.
    container.listen(recentSongsProvider, (_, _) {});
    container.listen(topSongsProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  Future<void> loadBoth() async {
    await container.read(recentSongsProvider.future);
    await container.read(topSongsProvider.future);
  }

  test('load the recent and the most played songs', () async {
    await loadBoth();
    expect(container.read(recentSongsProvider).value, [_song('a')]);
    expect(container.read(topSongsProvider).value, [_song('a')]);
  });

  test('a recorded play refreshes both lists', () async {
    await loadBoth();
    final audio = _FakeAudio();
    final recorder = HistoryRecorder(
      audio: audio,
      history: repo,
      events: container.read(historyEventsProvider),
    );
    addTearDown(recorder.dispose);

    repo.recent = [_song('b'), _song('a')];
    repo.top = [_song('b')];
    audio.started.add(_song('b'));
    await pumpEventQueue();
    await loadBoth();

    expect(repo.recorded, [_song('b')]);
    expect(container.read(recentSongsProvider).value, [_song('b'), _song('a')]);
    expect(container.read(topSongsProvider).value, [_song('b')]);
  });

  test('a failed record does not refresh the lists', () async {
    await loadBoth();
    final audio = _FakeAudio();
    final recorder = HistoryRecorder(
      audio: audio,
      history: repo,
      events: container.read(historyEventsProvider),
    );
    addTearDown(recorder.dispose);
    final calls = repo.recentCalls;

    repo.failure = const DatabaseFailure('disk full');
    audio.started.add(_song('b'));
    await pumpEventQueue();

    expect(repo.recentCalls, calls);
  });

  test('clearing the history refreshes both lists', () async {
    await loadBoth();
    await container.read(clearHistoryUseCaseProvider)();
    await pumpEventQueue();
    await loadBoth();

    expect(repo.clearCalls, 1);
    expect(container.read(recentSongsProvider).value, isEmpty);
    expect(container.read(topSongsProvider).value, isEmpty);
  });

  test('a failed load surfaces the typed failure', () async {
    const failure = DatabaseFailure('disk full');
    repo.failure = failure;
    container
      ..invalidate(recentSongsProvider)
      ..invalidate(topSongsProvider);
    await expectLater(
      container.read(recentSongsProvider.future),
      throwsA(failure),
    );
    await expectLater(
      container.read(topSongsProvider.future),
      throwsA(failure),
    );
  });
}
