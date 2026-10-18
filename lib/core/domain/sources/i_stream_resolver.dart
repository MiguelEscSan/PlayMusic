import 'package:sponify/core/domain/sources/source_registry.dart';

/// Obtiene una URL de streaming fresca a partir del id de la canción en su
/// origen. Hay una implementación por cada origen que la necesite; los
/// orígenes con URL estable no tienen. Puede lanzar si falla la red o el
/// origen bloquea la canción.
abstract interface class IStreamResolver implements SourceAdapter {
  Future<Uri> fetchStreamUrl(String sourceId);
}
