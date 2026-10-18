/// Un género que el usuario puede explorar desde Buscar.
///
/// No es una clasificación de canciones: es una búsqueda ya escrita. Tocar el
/// género hace exactamente lo mismo que buscar [query].
final class Genre {
  const Genre({required this.name, required this.query, required this.color});

  final String name;

  /// Texto que se busca al elegir el género.
  final String query;

  /// Color de la tarjeta, como ARGB (`0xFFRRGGBB`), para no depender de Flutter.
  final int color;
}

/// Géneros de la primera iteración. Cambiar el texto de búsqueda de uno no
/// toca nada más.
const genres = <Genre>[
  Genre(name: 'Pop', query: 'pop hits', color: 0xFF8D2F6B),
  Genre(name: 'Rock', query: 'rock classics', color: 0xFF1E6B4F),
  Genre(name: 'Latina', query: 'música latina éxitos', color: 0xFF0D6EFD),
  Genre(name: 'Hip hop', query: 'hip hop hits', color: 0xFF7A4B1F),
  Genre(name: 'Reguetón', query: 'reguetón éxitos', color: 0xFFB3261E),
  Genre(
    name: 'Electrónica',
    query: 'electronic dance music',
    color: 0xFF2D4DB3,
  ),
  Genre(name: 'Indie', query: 'indie playlist', color: 0xFF5E7D2E),
  Genre(name: 'R&B', query: 'r&b hits', color: 0xFF6B3FA0),
  Genre(name: 'Jazz', query: 'jazz classics', color: 0xFF8A6D1B),
  Genre(name: 'Clásica', query: 'música clásica', color: 0xFF4A5568),
  Genre(name: 'Metal', query: 'heavy metal classics', color: 0xFF3B3B3B),
  Genre(name: 'Chill', query: 'chill lofi', color: 0xFF2A7F8F),
];

/// Géneros cuyo nombre empieza por [typed] (sin mayúsculas ni tildes). Con
/// menos de dos letras no se propone ninguno.
List<Genre> matchGenres(String typed, {List<Genre> catalog = genres}) {
  final t = _fold(typed.trim());
  if (t.length < 2) return const [];
  return [
    for (final g in catalog)
      if (_fold(g.name).startsWith(t)) g,
  ];
}

String _fold(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i < 0 ? c : to[i]);
  }
  return b.toString();
}
