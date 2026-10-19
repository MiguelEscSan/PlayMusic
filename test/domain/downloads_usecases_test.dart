import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/song_key.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/download_task.dart';
import 'package:koda/features/downloads/domain/usecases/cancel_download_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/delete_all_downloads_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/delete_download_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/download_all_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/download_song_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/get_downloaded_songs_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/watch_download_tasks_use_case.dart';
import 'package:koda/features/downloads/domain/usecases/watch_downloads_changed_use_case.dart';

import 'fakes/fake_services.dart';
import 'fakes/fake_song_repository.dart';

Song _song(String id, {String? localPath}) => Song(
  id: '',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
  localPath: localPath,
);

const _failure = DatabaseFailure('disk full');

void main() {
  late FakeDownloadService service;

  setUp(() => service = FakeDownloadService());

  test('songKey identifies a song by its source, not its db id', () {
    expect(songKey(_song('a')), 'youtube:a');
    expect(songKey(_song('a').copyWith(id: 'x')), songKey(_song('a')));
  });

  group('GetDownloadedSongsUseCase', () {
    late FakeSongRepository songs;

    setUp(() => songs = FakeSongRepository());

    test('returns the downloaded songs', () async {
      songs.getDownloadedResult = Ok([_song('a')]);
      expect((await GetDownloadedSongsUseCase(songs)()).valueOrNull, [
        _song('a'),
      ]);
    });

    test('propagates the failure unchanged', () async {
      songs.getDownloadedResult = const Err(_failure);
      expect(
        (await GetDownloadedSongsUseCase(songs)()).failureOrNull,
        _failure,
      );
    });
  });

  test('WatchDownloadTasksUseCase exposes the task stream', () async {
    final task = DownloadTask(song: _song('a'), status: DownloadStatus.queued);
    final next = WatchDownloadTasksUseCase(service)().first;
    service.tasks.add({'youtube:a': task});
    expect(await next, {'youtube:a': task});
  });

  test('WatchDownloadsChangedUseCase exposes the change stream', () async {
    final next = WatchDownloadsChangedUseCase(service)().first;
    service.changes.add(_song('a'));
    expect((await next).sourceId, 'a');
  });

  group('DownloadSongUseCase', () {
    test('returns the song as saved by the service', () async {
      final result = await DownloadSongUseCase(service)(_song('a'));
      expect(result.valueOrNull?.id, 'saved-a');
      expect(service.downloadCalls.single.sourceId, 'a');
    });

    test('an exception becomes a StorageFailure', () async {
      service.error = Exception('io');
      expect(
        (await DownloadSongUseCase(service)(_song('a'))).failureOrNull,
        isA<StorageFailure>(),
      );
    });
  });

  group('DownloadAllUseCase', () {
    test('queues only the songs not downloaded yet', () async {
      final result = await DownloadAllUseCase(service)([
        _song('a'),
        _song('b', localPath: '/b.m4a'),
        _song('c'),
      ]);
      expect(result, const Ok(unit));
      expect([for (final s in service.downloadCalls) s.sourceId], ['a', 'c']);
    });

    test('an exception stops and becomes a StorageFailure', () async {
      service.error = Exception('io');
      final result = await DownloadAllUseCase(service)([
        _song('a'),
        _song('b'),
      ]);
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(service.downloadCalls, hasLength(1));
    });
  });

  group('CancelDownloadUseCase', () {
    test('cancels the download', () async {
      expect(await CancelDownloadUseCase(service)(_song('a')), const Ok(unit));
      expect(service.cancelCalls.single.sourceId, 'a');
    });

    test('an IO exception becomes a StorageFailure', () async {
      service.error = Exception('file locked');
      final result = await CancelDownloadUseCase(service)(_song('a'));
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(result.failureOrNull!.cause, same(service.error));
    });
  });

  group('DeleteDownloadUseCase', () {
    test('returns the song without its local file', () async {
      final result = await DeleteDownloadUseCase(service)(
        _song('a', localPath: '/a.m4a'),
      );
      expect(result.valueOrNull?.isDownloaded, isFalse);
    });

    test('propagates the failure unchanged', () async {
      service.deleteResult = const Err(_failure);
      expect(
        (await DeleteDownloadUseCase(service)(_song('a'))).failureOrNull,
        _failure,
      );
    });

    test('an exception becomes a StorageFailure', () async {
      service.error = Exception('io');
      expect(
        (await DeleteDownloadUseCase(service)(_song('a'))).failureOrNull,
        isA<StorageFailure>(),
      );
    });
  });

  group('DeleteAllDownloadsUseCase', () {
    test('deletes every download', () async {
      expect(await DeleteAllDownloadsUseCase(service)(), const Ok(unit));
      expect(service.deleteAllCalls, 1);
    });

    test('propagates the failure unchanged', () async {
      service.deleteAllResult = const Err(_failure);
      expect(
        (await DeleteAllDownloadsUseCase(service)()).failureOrNull,
        _failure,
      );
    });

    test('an exception becomes a StorageFailure', () async {
      service.error = Exception('io');
      expect(
        (await DeleteAllDownloadsUseCase(service)()).failureOrNull,
        isA<StorageFailure>(),
      );
    });
  });
}
