/// Resultado de buscar la letra de una canción.
sealed class Lyrics {
  const Lyrics();
}

/// Letra con marcas de tiempo (karaoke).
final class SyncedLyrics extends Lyrics {
  const SyncedLyrics(this.lines);
  final List<LyricLine> lines;
}

/// Letra sin sincronizar.
final class PlainLyrics extends Lyrics {
  const PlainLyrics(this.text);
  final String text;
}

final class InstrumentalLyrics extends Lyrics {
  const InstrumentalLyrics();
}

final class LyricsNotFound extends Lyrics {
  const LyricsNotFound();
}

/// Una línea de letra sincronizada: [time] es el instante en que empieza.
final class LyricLine {
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
