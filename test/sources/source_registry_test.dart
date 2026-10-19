import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/sources/source_registry.dart';

class _Adapter implements SourceAdapter {
  const _Adapter(this.source, [this.name = '']);

  @override
  final SongSource source;
  final String name;
}

Song _song(SongSource source) => Song(
  id: '1',
  title: 't',
  artist: 'a',
  durationMs: 1000,
  source: source,
  sourceId: 'x',
);

void main() {
  test('elige el adaptador del origen de la canción', () {
    const youtube = _Adapter(SongSource.youtube);
    const jamendo = _Adapter(SongSource.jamendo);
    final registry = SourceRegistry([youtube, jamendo]);

    expect(registry.forSong(_song(SongSource.youtube)), same(youtube));
    expect(registry.forSong(_song(SongSource.jamendo)), same(jamendo));
    expect(registry[SongSource.jamendo], same(jamendo));
  });

  test('null si ningún adaptador atiende el origen', () {
    final registry = SourceRegistry([const _Adapter(SongSource.youtube)]);

    expect(registry.forSong(_song(SongSource.local)), isNull);
    expect(const SourceRegistry<_Adapter>.empty()[SongSource.youtube], isNull);
  });

  test('con dos adaptadores del mismo origen gana el último', () {
    final registry = SourceRegistry([
      const _Adapter(SongSource.youtube, 'viejo'),
      const _Adapter(SongSource.youtube, 'nuevo'),
    ]);

    expect(registry[SongSource.youtube]!.name, 'nuevo');
  });
}
