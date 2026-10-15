import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../favorites/presentation/liked_home_section.dart';
import '../history/presentation/recent_home_section.dart';

/// Un bloque de la pantalla de Inicio (p. ej. "Te gusta", "Recientes").
///
/// Cada funcionalidad aporta su sección desde su propia carpeta; Inicio solo
/// las ordena por [order] y las pinta.
class HomeSection {
  const HomeSection({
    required this.id,
    required this.order,
    required this.builder,
    this.hasContent,
  });

  final String id;

  /// Menor = más arriba. Usar saltos de 10 para poder intercalar.
  final int order;
  final WidgetBuilder builder;

  /// false si ahora mismo no hay nada que enseñar (p. ej. sin favoritas).
  /// Si ninguna sección tiene contenido, Inicio muestra su estado vacío en
  /// vez de quedarse en blanco. null = siempre tiene contenido.
  final Provider<bool>? hasContent;
}

/// Secciones de Inicio. Para añadir una, sumar una línea a la lista con la
/// sección que expone la funcionalidad (una línea por funcionalidad, así las
/// ramas en paralelo apenas chocan).
final homeSectionsProvider = Provider<List<HomeSection>>(
  (ref) => [likedHomeSection, recentHomeSection],
);
