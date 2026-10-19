import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/sources/i_radio_source.dart';
import 'package:koda/core/domain/sources/source_registry.dart';

/// Radio falsa: devuelve lo que diga [_fetch] para su [source].
class FakeRadioSource implements IRadioSource {
  FakeRadioSource(this._fetch, {this.source = SongSource.youtube});

  final Future<List<Song>> Function(Song seed) _fetch;

  @override
  final SongSource source;

  @override
  Future<List<Song>> relatedTo(Song seed) => _fetch(seed);
}

/// Registro con una única radio falsa de YouTube.
SourceRegistry<IRadioSource> radioFrom(
  Future<List<Song>> Function(Song seed) fetch,
) => SourceRegistry([FakeRadioSource(fetch)]);
