import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/features/radio/domain/taste_ranker.dart';

Song _song(String id, String artist) => Song(
  id: '',
  title: 'T$id',
  artist: artist,
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: id,
);

List<String> _ids(List<Song> songs) => [for (final s in songs) s.sourceId];

void main() {
  test('sin gustos respeta el orden de YouTube', () {
    final ranked = rankByTaste([
      _song('a', 'A'),
      _song('b', 'B'),
      _song('c', 'C'),
    ], TasteProfile());
    expect(_ids(ranked), ['a', 'b', 'c']);
  });

  test('sube las de artistas con "me gusta" o muy escuchados', () {
    final ranked = rankByTaste(
      [
        _song('x0', 'Otro 0'),
        _song('x1', 'Otro 1'),
        _song('x2', 'Otro 2'),
        _song('liked', 'Rosalía'),
        _song('top', 'bad bunny'),
      ],
      TasteProfile(
        liked: [_song('l1', 'Rosalía'), _song('l2', 'ROSALÍA ')],
        top: [
          _song('t1', 'Bad Bunny'),
          _song('t2', 'Bad Bunny'),
          _song('t3', 'Bad Bunny'),
        ],
      ),
    );
    expect(_ids(ranked), ['liked', 'x0', 'x1', 'top', 'x2']);
  });

  test('quita las que sonaron hace poco', () {
    final ranked = rankByTaste([
      _song('a', 'A'),
      _song('b', 'B'),
      _song('c', 'C'),
    ], TasteProfile(recent: [_song('b', 'B')]));
    expect(_ids(ranked), ['a', 'c']);
  });

  test('si todas son recientes, las usa igualmente', () {
    final ranked = rankByTaste([
      _song('a', 'A'),
    ], TasteProfile(recent: [_song('a', 'A')]));
    expect(_ids(ranked), ['a']);
  });

  test('permite varias seguidas del mismo artista', () {
    final ranked = rankByTaste([
      _song('a1', 'A'),
      _song('a2', 'A'),
      _song('b1', 'B'),
      _song('a3', 'A'),
    ], TasteProfile());
    expect(_ids(ranked), ['a1', 'a2', 'b1', 'a3']);
  });
}
