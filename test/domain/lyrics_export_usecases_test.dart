import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/export/domain/i_song_exporter.dart';
import 'package:koda/features/export/domain/usecases/export_song_use_case.dart';
import 'package:koda/features/lyrics/domain/i_lyrics_repository.dart';
import 'package:koda/features/lyrics/domain/lyrics.dart';
import 'package:koda/features/lyrics/domain/usecases/get_lyrics_use_case.dart';

const _song = Song(
  id: '1',
  title: 'T',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'a',
  localPath: '/music/a.m4a',
);

class _FakeLyrics implements ILyricsRepository {
  _FakeLyrics(this.result);

  final Future<Result<Lyrics>> Function() result;
  final requested = <(String, String)>[];

  @override
  Future<Result<Lyrics>> getLyrics(
    String title,
    String artist, {
    int durationSeconds = 0,
  }) {
    requested.add((title, artist));
    return result();
  }
}

class _FakeExporter implements ISongExporter {
  _FakeExporter(this.result);

  final Future<Result<String>> Function() result;

  @override
  Future<Result<String>> export(Song song) => result();
}

void main() {
  group('GetLyricsUseCase', () {
    test('returns the lyrics of the song', () async {
      final repo = _FakeLyrics(() async => const Ok(PlainLyrics('hola')));
      final result = await GetLyricsUseCase(repo)(_song);
      expect((result.valueOrNull! as PlainLyrics).text, 'hola');
      expect(repo.requested, [(_song.title, _song.artist)]);
    });

    test('propagates the failure', () async {
      const failure = NetworkFailure('sin red');
      final repo = _FakeLyrics(() async => const Err(failure));
      expect((await GetLyricsUseCase(repo)(_song)).failureOrNull, failure);
    });

    test('an unexpected throw becomes Err', () async {
      final repo = _FakeLyrics(() async => throw StateError('boom'));
      expect(
        (await GetLyricsUseCase(repo)(_song)).failureOrNull,
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('ExportSongUseCase', () {
    test('returns where the file was saved', () async {
      final exporter = _FakeExporter(() async => const Ok('Música/Koda'));
      expect(await ExportSongUseCase(exporter)(_song), const Ok('Música/Koda'));
    });

    test('keeps the kind of export error', () async {
      final exporter = _FakeExporter(
        () async => Err(SongExportFailure(SongExportError.permissionDenied)),
      );
      final failure = (await ExportSongUseCase(exporter)(_song)).failureOrNull;
      expect(
        failure,
        isA<SongExportFailure>().having(
          (f) => f.error,
          'error',
          SongExportError.permissionDenied,
        ),
      );
    });

    test('an unexpected throw becomes a generic export failure', () async {
      final exporter = _FakeExporter(() async => throw StateError('boom'));
      final failure = (await ExportSongUseCase(exporter)(_song)).failureOrNull;
      expect(
        failure,
        isA<SongExportFailure>().having(
          (f) => f.error,
          'error',
          SongExportError.failed,
        ),
      );
    });
  });
}
