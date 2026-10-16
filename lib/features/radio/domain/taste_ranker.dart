import 'package:sponify/core/domain/entities/song.dart';

/// Lo que sabemos de los gustos del usuario, a partir de sus "me gusta" y
/// de su historial. YouTube no da género, así que la afinidad es por
/// artista.
class TasteProfile {
  TasteProfile({
    List<Song> liked = const [],
    List<Song> top = const [],
    List<Song> recent = const [],
  }) : likedKeys = {for (final s in liked) songKey(s)},
       recentKeys = {for (final s in recent) songKey(s)},
       _artistWeight = _weights(liked, top);

  /// Canciones con "me gusta".
  final Set<String> likedKeys;

  /// Canciones que sonaron hace poco: no se repiten.
  final Set<String> recentKeys;

  final Map<String, double> _artistWeight;

  /// Cada "me gusta" suma 1 a su artista y cada canción entre las más
  /// escuchadas, 0,5.
  static Map<String, double> _weights(List<Song> liked, List<Song> top) {
    final w = <String, double>{};
    for (final s in liked) {
      w.update(artistKey(s.artist), (v) => v + 1, ifAbsent: () => 1);
    }
    for (final s in top) {
      w.update(artistKey(s.artist), (v) => v + 0.5, ifAbsent: () => 0.5);
    }
    return w;
  }

  /// Entre 0 (artista desconocido) y 1 (tres "me gusta" o más).
  double artistAffinity(String artist) {
    final w = _artistWeight[artistKey(artist)] ?? 0;
    return w >= 3 ? 1 : w / 3;
  }

  static String songKey(Song s) => '${s.source.name}:${s.sourceId}';

  static String artistKey(String artist) => artist.trim().toLowerCase();
}

/// Ordena las candidatas de la radio: respeta el orden de YouTube (las
/// primeras se parecen más a la semilla) pero sube las de artistas que
/// gustan y quita las que sonaron hace poco. Puede haber varias seguidas
/// del mismo artista.
///
/// Si quitar las recientes deja la lista vacía, se usan igualmente: mejor
/// repetir que quedarse en silencio.
List<Song> rankByTaste(List<Song> candidates, TasteProfile taste) {
  final fresh = [
    for (final s in candidates)
      if (!taste.recentKeys.contains(TasteProfile.songKey(s))) s,
  ];
  final pool = fresh.isEmpty ? candidates : fresh;
  final n = pool.length;
  final scored = [
    for (var i = 0; i < n; i++)
      (
        song: pool[i],
        score:
            (1 - i / n) +
            taste.artistAffinity(pool[i].artist) +
            (taste.likedKeys.contains(TasteProfile.songKey(pool[i])) ? 0.3 : 0),
      ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return [for (final e in scored) e.song];
}
