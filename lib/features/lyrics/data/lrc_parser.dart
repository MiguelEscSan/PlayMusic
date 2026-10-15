import 'package:flutter/foundation.dart';

/// Una línea de letra sincronizada: [time] es el instante en que empieza.
@immutable
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => 'LyricLine($time, "$text")';
}

/// Marca de tiempo LRC: `[mm:ss]`, `[mm:ss.xx]` o `[mm:ss.xxx]`.
final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Etiqueta de desfase global: `[offset:+500]` (milisegundos). Un valor
/// positivo adelanta la letra (aparece antes).
final _offsetTag = RegExp(
  r'^\[offset:\s*([+-]?\d+)\s*\]',
  caseSensitive: false,
);

/// Convierte texto LRC en líneas ordenadas por tiempo.
///
/// - Una línea con varias marcas (`[00:05][00:30]Estribillo`) genera una
///   entrada por marca.
/// - Las etiquetas de metadatos (`[ar:]`, `[ti:]`, `[length:]`…) y las líneas
///   sin marca se ignoran; `[offset:]` se aplica.
/// - Las líneas con marca pero sin texto se conservan (pausas instrumentales).
List<LyricLine> parseLrc(String lrc) {
  final result = <LyricLine>[];
  var offsetMs = 0;

  for (final raw in lrc.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final offset = _offsetTag.firstMatch(line);
    if (offset != null) {
      offsetMs = int.parse(offset.group(1)!);
      continue;
    }

    // Solo cuentan las marcas consecutivas al principio de la línea.
    final times = <Duration>[];
    var rest = line;
    while (true) {
      final match = _timeTag.matchAsPrefix(rest);
      if (match == null) break;
      times.add(_toDuration(match));
      rest = rest.substring(match.end);
    }
    if (times.isEmpty) continue;

    final text = rest.trim();
    for (final time in times) {
      result.add(LyricLine(time, text));
    }
  }

  if (offsetMs != 0) {
    for (var i = 0; i < result.length; i++) {
      final shifted = result[i].time - Duration(milliseconds: offsetMs);
      result[i] = LyricLine(
        shifted.isNegative ? Duration.zero : shifted,
        result[i].text,
      );
    }
  }

  // Ordenación estable: a igual tiempo se respeta el orden del archivo.
  mergeSort(result, compare: (a, b) => a.time.compareTo(b.time));
  return result;
}

Duration _toDuration(Match match) {
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3);
  var millis = 0;
  if (fraction != null) {
    // "5" -> 500 ms, "50" -> 500 ms, "500" -> 500 ms.
    millis = int.parse(fraction.padRight(3, '0'));
  }
  return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
}

/// Índice de la línea que suena en [position] (la última cuyo tiempo ya
/// pasó), o -1 si aún no ha empezado ninguna. Búsqueda binaria: se llama
/// varias veces por segundo.
int currentLineIndex(List<LyricLine> lines, Duration position) {
  var low = 0;
  var high = lines.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (lines[mid].time <= position) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}
