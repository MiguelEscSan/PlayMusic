import 'package:flutter_test/flutter_test.dart';
import 'package:koda/features/search/domain/genre.dart';

void main() {
  test('el catálogo no repite nombres ni textos de búsqueda', () {
    expect(genres.map((g) => g.name).toSet().length, genres.length);
    expect(genres.map((g) => g.query).toSet().length, genres.length);
  });

  test('matchGenres ignora mayúsculas y tildes', () {
    expect(matchGenres('ROC').map((g) => g.name), ['Rock']);
    expect(matchGenres('reguet').map((g) => g.name), ['Reguetón']);
    expect(matchGenres('clasi').map((g) => g.name), ['Clásica']);
  });

  test('matchGenres no propone nada con menos de dos letras', () {
    expect(matchGenres('r'), isEmpty);
    expect(matchGenres(''), isEmpty);
  });

  test('matchGenres no encuentra textos que no son un género', () {
    expect(matchGenres('bad bunny'), isEmpty);
  });
}
