import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/models/playlist.dart';
import 'package:sponify/core/models/song.dart';

Song _song(String id, {String? localPath, String? art}) => Song(
  id: id,
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$id',
  localPath: localPath,
  artworkUrl: art,
);

Playlist _withSongs(List<Song> songs, {String? coverUrl}) {
  final now = DateTime.now();
  return Playlist(
    id: 'p',
    name: 'Mix',
    coverUrl: coverUrl,
    createdAt: now,
    updatedAt: now,
    songs: songs,
  );
}

void main() {
  test('Song: toMap/fromMap ida y vuelta', () {
    final s = _song('1', localPath: '/x.m4a');
    final back = Song.fromMap(s.toMap());
    expect(back, s);
    expect(back.localPath, '/x.m4a');
    expect(back.isDownloaded, isTrue);
  });

  test('Song: clearLocalFile vuelve a streaming', () {
    final s = _song('1', localPath: '/x.m4a').copyWith(clearLocalFile: true);
    expect(s.isDownloaded, isFalse);
  });

  test('Playlist: reorder y contadores', () {
    final now = DateTime.now();
    final p = Playlist(
      id: 'p',
      name: 'Mix',
      createdAt: now,
      updatedAt: now,
      songs: [
        _song('1'),
        _song('2', localPath: '/2'),
        _song('3'),
      ],
    );
    expect(p.downloadedCount, 1);
    final r = p.reorder(0, 3);
    expect(r.songs.map((s) => s.id), ['2', '3', '1']);
  });

  group('Playlist.coverUrls', () {
    test('mosaico con las 4 primeras carátulas distintas', () {
      final p = _withSongs([
        _song('1', art: 'a'),
        _song('2', art: 'a'),
        _song('3'),
        _song('4', art: 'b'),
        _song('5', art: 'c'),
        _song('6', art: 'd'),
        _song('7', art: 'e'),
      ]);
      expect(p.coverUrls, ['a', 'b', 'c', 'd']);
    });

    test('con menos de 4 carátulas distintas, solo la primera', () {
      final p = _withSongs([_song('1', art: 'a'), _song('2', art: 'b')]);
      expect(p.coverUrls, ['a']);
    });

    test('la portada personalizada manda', () {
      final p = _withSongs([
        for (final x in ['a', 'b', 'c', 'd']) _song(x, art: x),
      ], coverUrl: 'mine');
      expect(p.coverUrls, ['mine']);
    });

    test('sin carátulas, vacía', () {
      expect(_withSongs([_song('1')]).coverUrls, isEmpty);
      expect(_withSongs([]).coverUrls, isEmpty);
    });
  });

  group('Song: me gusta', () {
    test('fromMap lee liked_at y toMap no lo escribe', () {
      final map = {..._song('1').toMap(), 'liked_at': 1700000000000};
      final s = Song.fromMap(map);
      expect(s.isLiked, isTrue);
      expect(s.likedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(s.toMap().containsKey('liked_at'), isFalse);
      expect(Song.fromMap(_song('1').toMap()).isLiked, isFalse);
    });

    test('copyWith pone y quita el me gusta', () {
      final liked = _song('1').copyWith(likedAt: DateTime(2026));
      expect(liked.isLiked, isTrue);
      expect(liked.copyWith(title: 'x').isLiked, isTrue);
      expect(liked.copyWith(clearLiked: true).isLiked, isFalse);
    });
  });
}
