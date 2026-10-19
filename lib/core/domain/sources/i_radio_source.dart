import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/sources/source_registry.dart';

/// Canciones parecidas a una semilla de su origen (p. ej. el Mix de
/// YouTube), sin guardar todavía. Puede lanzar si falla la red.
abstract interface class IRadioSource implements SourceAdapter {
  Future<List<Song>> relatedTo(Song seed);
}
