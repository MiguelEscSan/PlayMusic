import '../../../core/utils/formatters.dart';
import '../domain/i_playlist_importer.dart';

/// Texto que resume una importación: cuántas se importaron, cuántas se
/// omitieron y, si el origen no dejó leerlas todas (Spotify sin sesión),
/// qué hacer con el resto.
String importSummary(ImportResult result) {
  final verb = result.imported == 1 ? 'Importada' : 'Importadas';
  final skipped = result.skipped > 0 ? ' (${result.skipped} omitidas)' : '';
  if (result.isPartial) {
    return '$verb ${result.imported} de ${result.remoteTotal}$skipped. '
        'Spotify solo deja leer las ${result.read} primeras sin iniciar '
        'sesión: añade el resto a otra playlist pública y pega su enlace.';
  }
  return '$verb ${songCount(result.imported)}$skipped';
}
