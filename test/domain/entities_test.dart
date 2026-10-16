import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';

Song _song(String id, {String? artwork, String? localPath, int ms = 1000}) =>
    Song(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      durationMs: ms,
      source: SongSource.youtube,
      sourceId: 'yt-$id',
      artworkUrl: artwork,
      localPath: localPath,
    );

Playlist _playlist(List<Song> songs, {String? coverUrl, DateTime? updatedAt}) =>
    Playlist(
      id: 'p1',
      name: 'Mix',
      createdAt: DateTime(2026),
      updatedAt: updatedAt ?? DateTime(2026),
      coverUrl: coverUrl,
      songs: songs,
    );

void main() {
  group('Song', () {
    final downloaded = _song('a', localPath: '/music/a.m4a').copyWith(
      fileSizeBytes: 123,
      downloadedAt: DateTime(2026),
      likedAt: DateTime(2026),
    );

    test('derives isLiked, isDownloaded and duration', () {
      expect(downloaded.isLiked, isTrue);
      expect(downloaded.isDownloaded, isTrue);
      expect(downloaded.duration, const Duration(seconds: 1));
      expect(_song('b').isLiked, isFalse);
      expect(_song('b').isDownloaded, isFalse);
    });

    test('copyWith(clearLocalFile) clears path, size and date only', () {
      final cleared = downloaded.copyWith(clearLocalFile: true);

      expect(cleared.localPath, isNull);
      expect(cleared.fileSizeBytes, isNull);
      expect(cleared.downloadedAt, isNull);
      expect(cleared.isDownloaded, isFalse);
      expect(cleared.likedAt, downloaded.likedAt);
    });

    test('copyWith(clearLiked) clears likedAt only', () {
      final cleared = downloaded.copyWith(clearLiked: true);

      expect(cleared.likedAt, isNull);
      expect(cleared.localPath, downloaded.localPath);
    });

    test('equality is by source and sourceId', () {
      final a = _song('a');
      final sameOrigin = a.copyWith(id: 'other', title: 'Renamed');
      final otherOrigin = a.copyWith(sourceId: 'yt-zzz');

      expect(a, sameOrigin);
      expect(a.hashCode, sameOrigin.hashCode);
      expect(a, isNot(otherOrigin));
    });
  });

  group('Playlist', () {
    test('aggregates length, duration and download state', () {
      final playlist = _playlist([
        _song('a', localPath: '/a', ms: 1000),
        _song('b', ms: 2000),
      ]);

      expect(playlist.length, 2);
      expect(playlist.isEmpty, isFalse);
      expect(playlist.totalDuration, const Duration(seconds: 3));
      expect(playlist.downloadedCount, 1);
      expect(playlist.isFullyDownloaded, isFalse);
    });

    test('isFullyDownloaded is false when empty and true when all local', () {
      expect(_playlist(const []).isFullyDownloaded, isFalse);
      expect(
        _playlist([_song('a', localPath: '/a'), _song('b', localPath: '/b')])
            .isFullyDownloaded,
        isTrue,
      );
    });

    test('effectiveCoverUrl prefers the custom cover, then first artwork', () {
      expect(_playlist(const []).effectiveCoverUrl, isNull);
      expect(
        _playlist([_song('a', artwork: 'art-a')]).effectiveCoverUrl,
        'art-a',
      );
      expect(
        _playlist([
          _song('a', artwork: 'art-a'),
        ], coverUrl: 'custom').effectiveCoverUrl,
        'custom',
      );
    });

    group('coverUrls', () {
      test('is the custom cover alone when set', () {
        final playlist = _playlist([
          _song('a', artwork: '1'),
        ], coverUrl: 'custom');

        expect(playlist.coverUrls, ['custom']);
      });

      test('is empty when no song has artwork', () {
        expect(_playlist([_song('a'), _song('b')]).coverUrls, isEmpty);
      });

      test('is only the first artwork with fewer than 4 distinct', () {
        final playlist = _playlist([
          _song('a', artwork: '1'),
          _song('b', artwork: '1'),
          _song('c', artwork: '2'),
          _song('d'),
          _song('e', artwork: '3'),
        ]);

        expect(playlist.coverUrls, ['1']);
      });

      test('is a 2x2 mosaic of the first 4 distinct artworks', () {
        final playlist = _playlist([
          _song('a', artwork: '1'),
          _song('b', artwork: '1'),
          _song('c', artwork: '2'),
          _song('d', artwork: '3'),
          _song('e', artwork: '4'),
          _song('f', artwork: '5'),
        ]);

        expect(playlist.coverUrls, ['1', '2', '3', '4']);
      });
    });

    group('reorder', () {
      final a = _song('a');
      final b = _song('b');
      final c = _song('c');

      test('moves a song down (ReorderableListView semantics)', () {
        final reordered = _playlist([a, b, c]).reorder(0, 2);

        expect(reordered.songs, [b, a, c]);
      });

      test('moves a song up', () {
        final reordered = _playlist([a, b, c]).reorder(2, 0);

        expect(reordered.songs, [c, a, b]);
      });

      test('bumps updatedAt and keeps the original untouched', () {
        final original = _playlist([a, b, c]);

        final reordered = original.reorder(0, 3);

        expect(reordered.songs, [b, c, a]);
        expect(reordered.updatedAt.isAfter(original.updatedAt), isTrue);
        expect(original.songs, [a, b, c]);
      });
    });

    test('equality uses id, updatedAt and the song list', () {
      final a = _song('a');
      final b = _song('b');

      expect(_playlist([a, b]), _playlist([a, b]));
      expect(_playlist([a, b]).hashCode, _playlist([a, b]).hashCode);
      expect(_playlist([a, b]), isNot(_playlist([b, a])));
      expect(
        _playlist([a, b]),
        isNot(_playlist([a, b], updatedAt: DateTime(2027))),
      );
    });

    test('copyWith keeps id and createdAt', () {
      final copy = _playlist(const []).copyWith(name: 'Renamed');

      expect(copy.id, 'p1');
      expect(copy.createdAt, DateTime(2026));
      expect(copy.name, 'Renamed');
    });
  });
}
