import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/features/lyrics/data/lrc_parser.dart';
import 'package:sponify/features/lyrics/domain/lyrics.dart';

void main() {
  group('parseLrc', () {
    test('parsea [mm:ss.xx] y ordena por tiempo', () {
      final lines = parseLrc('[00:12.50] Segunda\n[00:01.00] Primera');
      expect(lines, const [
        LyricLine(Duration(seconds: 1), 'Primera'),
        LyricLine(Duration(seconds: 12, milliseconds: 500), 'Segunda'),
      ]);
    });

    test('admite [mm:ss] y [mm:ss.xxx]', () {
      final lines = parseLrc('[01:02] A\n[01:03.123] B');
      expect(lines.map((l) => l.time), const [
        Duration(minutes: 1, seconds: 2),
        Duration(minutes: 1, seconds: 3, milliseconds: 123),
      ]);
    });

    test('varias marcas en la misma línea generan varias líneas', () {
      final lines = parseLrc('[00:05.00][00:30.00]Estribillo\n[00:10.00]Otra');
      expect(lines.map((l) => l.text), ['Estribillo', 'Otra', 'Estribillo']);
      expect(lines.last.time, const Duration(seconds: 30));
    });

    test('ignora etiquetas de metadatos y líneas sin marca', () {
      final lines = parseLrc(
        '[ar:Artista]\n[ti:Título]\n[length:03:20]\ntexto suelto\n'
        '[00:01.00]Hola',
      );
      expect(lines, const [LyricLine(Duration(seconds: 1), 'Hola')]);
    });

    test('aplica [offset:] en milisegundos', () {
      final lines = parseLrc('[offset:500]\n[00:02.00]Hola');
      expect(lines.single.time, const Duration(milliseconds: 1500));
    });

    test(
      'conserva líneas vacías (pausas instrumentales) y recorta espacios',
      () {
        final lines = parseLrc('[00:01.00]  Hola  \r\n[00:04.00]');
        expect(lines.map((l) => l.text), ['Hola', '']);
      },
    );

    test('texto vacío devuelve lista vacía', () {
      expect(parseLrc(''), isEmpty);
    });
  });

  group('currentLineIndex', () {
    const lines = [
      LyricLine(Duration(seconds: 1), 'a'),
      LyricLine(Duration(seconds: 5), 'b'),
      LyricLine(Duration(seconds: 9), 'c'),
    ];

    test('antes de la primera línea devuelve -1', () {
      expect(currentLineIndex(lines, Duration.zero), -1);
    });

    test('devuelve la última línea cuyo tiempo ya pasó', () {
      expect(currentLineIndex(lines, const Duration(seconds: 1)), 0);
      expect(currentLineIndex(lines, const Duration(seconds: 6)), 1);
      expect(currentLineIndex(lines, const Duration(minutes: 3)), 2);
    });
  });
}
