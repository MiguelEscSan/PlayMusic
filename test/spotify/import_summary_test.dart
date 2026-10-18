import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/features/playlists/domain/i_playlist_importer.dart';
import 'package:sponify/features/playlists/presentation/import_summary.dart';

ImportResult _r(int imported, int skipped, [int? total]) => ImportResult(
  playlistId: 'p',
  imported: imported,
  skipped: skipped,
  remoteTotal: total,
);

void main() {
  test('sin total remoto, el mensaje de siempre', () {
    expect(importSummary(_r(3, 0)), 'Importadas 3 canciones');
    expect(importSummary(_r(1, 2)), 'Importada 1 canción (2 omitidas)');
  });

  test('si se leyó todo, no avisa del límite', () {
    expect(
      importSummary(_r(120, 2, 122)),
      'Importadas 120 canciones '
      '(2 omitidas)',
    );
  });

  test('100 de 122: explica el límite de Spotify', () {
    expect(
      importSummary(_r(100, 0, 122)),
      'Importadas 100 de 122. Spotify solo deja leer las 100 primeras sin '
      'iniciar sesión: añade el resto a otra playlist pública y pega su '
      'enlace.',
    );
  });

  test('parcial y con omitidas: incluye las dos cosas', () {
    expect(
      importSummary(_r(95, 5, 122)),
      'Importadas 95 de 122 (5 omitidas). Spotify solo deja leer las 100 '
      'primeras sin iniciar sesión: añade el resto a otra playlist pública y '
      'pega su enlace.',
    );
  });
}
