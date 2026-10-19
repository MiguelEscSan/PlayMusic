import 'package:koda/core/domain/entities/song.dart';

/// Adaptador de un origen de música concreto (YouTube, Jamendo…).
abstract interface class SourceAdapter {
  /// Origen que atiende: el `Song.source` de sus canciones.
  SongSource get source;
}

/// Elige el adaptador de cada origen. Añadir un origen nuevo es escribir su
/// adaptador y registrarlo aquí; el resto de la app no cambia.
final class SourceRegistry<T extends SourceAdapter> {
  /// Si dos adaptadores atienden el mismo origen gana el último.
  SourceRegistry(Iterable<T> adapters)
    : _adapters = {for (final a in adapters) a.source: a};

  const SourceRegistry.empty() : _adapters = const {};

  final Map<SongSource, T> _adapters;

  /// El adaptador de [source]; null si ninguno lo atiende.
  T? operator [](SongSource source) => _adapters[source];

  /// El adaptador del origen de [song]; null si ninguno lo atiende.
  T? forSong(Song song) => _adapters[song.source];
}
