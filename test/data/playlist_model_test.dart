import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/data/models/playlist_model.dart';
import 'package:sponify/core/data/models/song_model.dart';
import 'package:sponify/core/domain/entities/playlist.dart' as domain;

SongModel _song(String id) => SongModel(
  id: 'song-$id',
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
  downloadProgress: 0.3,
);

void main() {
  final createdAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(1700000900000);

  PlaylistModel model() => PlaylistModel(
    id: 'pl-1',
    name: 'Mix',
    description: 'Desc',
    coverUrl: '/covers/pl-1.jpg',
    createdAt: createdAt,
    updatedAt: updatedAt,
    songs: [_song('3'), _song('1'), _song('2')],
  );

  test('toEntity copies fields and keeps songs in order', () {
    final entity = model().toEntity();

    expect(entity, isA<domain.Playlist>());
    expect(entity.id, 'pl-1');
    expect(entity.name, 'Mix');
    expect(entity.description, 'Desc');
    expect(entity.coverUrl, '/covers/pl-1.jpg');
    expect(entity.createdAt, createdAt);
    expect(entity.updatedAt, updatedAt);
    expect([for (final s in entity.songs) s.title], ['T3', 'T1', 'T2']);
    expect(
      [for (final s in entity.songs) s.id],
      ['song-3', 'song-1', 'song-2'],
    );
  });

  test('fromEntity -> toEntity round-trip preserves fields and order', () {
    final entity = model().toEntity();
    final back = PlaylistModel.fromEntity(entity);

    expect(back.id, entity.id);
    expect(back.name, entity.name);
    expect(back.description, entity.description);
    expect(back.coverUrl, entity.coverUrl);
    expect(back.createdAt, entity.createdAt);
    expect(back.updatedAt, entity.updatedAt);
    expect([for (final s in back.songs) s.sourceId], ['3', '1', '2']);
    expect(
      back.songs.every((s) => s.downloadProgress == null),
      isTrue,
      reason: 'downloadProgress is UI state, dropped by the domain',
    );
    expect(back.toEntity(), entity);
  });

  test('empty playlist maps to an empty song list', () {
    final empty = PlaylistModel(
      id: 'pl-2',
      name: 'Empty',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    final entity = empty.toEntity();

    expect(entity.songs, isEmpty);
    expect(entity.description, isNull);
    expect(entity.coverUrl, isNull);
    expect(PlaylistModel.fromEntity(entity).songs, isEmpty);
  });
}
