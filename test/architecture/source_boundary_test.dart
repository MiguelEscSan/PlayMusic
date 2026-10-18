import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Carpeta del adaptador de YouTube: lo único que puede usar
/// youtube_explode_dart o el cliente InnerTube.
const _youtubeAdapter = 'lib/sources/youtube';

/// Raíz de composición: el único sitio fuera de los adaptadores que puede
/// importarlos, para registrarlos.
bool _isCompositionRoot(String path) =>
    path == 'lib/bootstrap.dart' || p.isWithin('lib/di', path);

final _import = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Ruta de [uri] dentro del proyecto (`lib/...`) si es un archivo de la app,
/// o el propio [uri] si es de un paquete externo.
String _resolve(String file, String uri) {
  if (uri.startsWith('package:sponify/')) {
    return 'lib/${uri.substring('package:sponify/'.length)}';
  }
  if (uri.contains(':')) return uri;
  return p.posix.normalize(p.posix.join(p.posix.dirname(file), uri));
}

/// Imports de [file] (ruta `lib/...` con `/`) que se saltan la frontera del
/// origen de música.
List<String> sourceBoundaryViolations(String file, String source) {
  if (p.isWithin(_youtubeAdapter, file)) return const [];
  final violations = <String>[];
  for (final match in _import.allMatches(source)) {
    final uri = match.group(1)!;
    final target = _resolve(file, uri);
    final youtubeLibrary =
        target.startsWith('package:youtube_explode_dart/') ||
        target.endsWith('youtube_innertube.dart');
    final adapter = p.isWithin('lib/sources', target);
    if (youtubeLibrary || (adapter && !_isCompositionRoot(file))) {
      violations.add('$file -> $uri');
    }
  }
  return violations;
}

void main() {
  test('solo el adaptador de YouTube usa youtube_explode o InnerTube, y '
      'solo la raíz de composición importa los adaptadores', () {
    final violations = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          ...sourceBoundaryViolations(
            p.split(entity.path).join('/'),
            entity.readAsStringSync(),
          ),
    ];

    expect(violations, isEmpty);
  });

  group('la regla detecta', () {
    test('youtube_explode en una feature', () {
      expect(
        sourceBoundaryViolations(
          'lib/features/search/data/x.dart',
          "import 'package:youtube_explode_dart/youtube_explode_dart.dart';",
        ),
        hasLength(1),
      );
    });

    test('el cliente InnerTube o un adaptador importado desde core', () {
      expect(
        sourceBoundaryViolations('lib/core/audio/x.dart', '''
import '../../sources/youtube/youtube_innertube.dart';
import 'package:sponify/sources/youtube/youtube_track_search.dart';
'''),
        hasLength(2),
      );
    });

    test('youtube_explode en la raíz de composición', () {
      expect(
        sourceBoundaryViolations(
          'lib/bootstrap.dart',
          "import 'package:youtube_explode_dart/youtube_explode_dart.dart';",
        ),
        hasLength(1),
      );
    });
  });

  test('la raíz de composición sí puede registrar adaptadores, y los '
      'puertos de dominio no cuentan como adaptadores', () {
    expect(
      sourceBoundaryViolations('lib/di/service_providers.dart', '''
import '../sources/youtube/youtube_track_search.dart';
import '../core/domain/sources/i_track_search.dart';
'''),
      isEmpty,
    );
    expect(
      sourceBoundaryViolations(
        'lib/features/radio/domain/radio_service.dart',
        "import 'package:sponify/core/domain/sources/i_radio_source.dart';",
      ),
      isEmpty,
    );
  });
}
