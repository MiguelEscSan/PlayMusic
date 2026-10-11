import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/models/playlist.dart';
import 'package:sponify/core/models/song.dart';

Song _song(String id, {String? localPath}) => Song(
  id: id,
  title: 'T$id',
  artist: 'A',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$id',
  localPath: localPath,
);

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
}
