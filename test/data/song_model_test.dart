import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/domain/entities/song.dart' as domain;

void main() {
  final downloadedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final likedAt = DateTime.fromMillisecondsSinceEpoch(1700000500000);

  SongModel fullModel() => SongModel(
    id: 'id-1',
    title: 'Title',
    artist: 'Artist',
    album: 'Album',
    durationMs: 215000,
    artworkUrl: 'https://img/1.jpg',
    source: SongSource.youtube,
    sourceId: 'yt-1',
    streamUrl: 'https://stream/1',
    localPath: '/music/1.m4a',
    fileSizeBytes: 4096,
    downloadedAt: downloadedAt,
    downloadProgress: 0.5,
    likedAt: likedAt,
  );

  group('SongModel map serialization', () {
    test('toMap/fromMap round-trip keeps every persisted column', () {
      final map = fullModel().toMap();
      final restored = SongModel.fromMap(map);

      expect(restored.id, 'id-1');
      expect(restored.title, 'Title');
      expect(restored.artist, 'Artist');
      expect(restored.album, 'Album');
      expect(restored.durationMs, 215000);
      expect(restored.artworkUrl, 'https://img/1.jpg');
      expect(restored.source, SongSource.youtube);
      expect(restored.sourceId, 'yt-1');
      expect(restored.streamUrl, 'https://stream/1');
      expect(restored.localPath, '/music/1.m4a');
      expect(restored.fileSizeBytes, 4096);
      expect(restored.downloadedAt, downloadedAt);
      expect(restored.downloadProgress, isNull, reason: 'not persisted');
      expect(restored, fullModel(), reason: 'equal by source + sourceId');
      expect(restored.isDownloaded, isTrue);
      expect(restored.isLiked, isFalse, reason: 'liked_at is not in toMap');
    });

    test('likedAt is read by fromMap but never written by toMap', () {
      final map = fullModel().toMap();
      expect(map.containsKey('liked_at'), isFalse);

      final restored = SongModel.fromMap({
        ...map,
        'liked_at': likedAt.millisecondsSinceEpoch,
      });
      expect(restored.likedAt, likedAt);
      expect(restored.isLiked, isTrue);
    });
  });

  group('SongModel entity mappers', () {
    test('toEntity copies every field except downloadProgress', () {
      final entity = fullModel().toEntity();

      expect(entity, isA<domain.Song>());
      expect(entity.id, 'id-1');
      expect(entity.title, 'Title');
      expect(entity.artist, 'Artist');
      expect(entity.album, 'Album');
      expect(entity.durationMs, 215000);
      expect(entity.artworkUrl, 'https://img/1.jpg');
      expect(entity.source, domain.SongSource.youtube);
      expect(entity.sourceId, 'yt-1');
      expect(entity.streamUrl, 'https://stream/1');
      expect(entity.localPath, '/music/1.m4a');
      expect(entity.fileSizeBytes, 4096);
      expect(entity.downloadedAt, downloadedAt);
      expect(entity.likedAt, likedAt);
    });

    test('fromEntity -> toEntity round-trip preserves all fields', () {
      final entity = fullModel().toEntity();
      final model = SongModel.fromEntity(entity);
      final back = model.toEntity();

      expect(model.downloadProgress, isNull);
      expect(back.id, entity.id);
      expect(back.title, entity.title);
      expect(back.artist, entity.artist);
      expect(back.album, entity.album);
      expect(back.durationMs, entity.durationMs);
      expect(back.artworkUrl, entity.artworkUrl);
      expect(back.source, entity.source);
      expect(back.sourceId, entity.sourceId);
      expect(back.streamUrl, entity.streamUrl);
      expect(back.localPath, entity.localPath);
      expect(back.fileSizeBytes, entity.fileSizeBytes);
      expect(back.downloadedAt, entity.downloadedAt);
      expect(back.likedAt, entity.likedAt);
    });

    test('nullable fields survive the mapping as null', () {
      const entity = domain.Song(
        id: 'id-2',
        title: 'T',
        artist: 'A',
        durationMs: 1,
        source: domain.SongSource.jamendo,
        sourceId: 'j-2',
      );
      final back = SongModel.fromEntity(entity).toEntity();

      expect(back.album, isNull);
      expect(back.artworkUrl, isNull);
      expect(back.streamUrl, isNull);
      expect(back.localPath, isNull);
      expect(back.fileSizeBytes, isNull);
      expect(back.downloadedAt, isNull);
      expect(back.likedAt, isNull);
      expect(back.source, domain.SongSource.jamendo);
    });
  });
}
