import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Carátula cuadrada con caché en disco y un icono mientras carga o si
/// falla (p. ej. sin conexión y sin caché).
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    this.size = 48,
    this.radius = 6,
    this.seed,
  });

  final String? url;

  /// Texto (p. ej. el título) del que sale el color de la portada generada
  /// cuando no hay imagen o no carga sin conexión.
  final String? seed;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _GeneratedCover(seed: seed ?? url ?? '', size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              // Las miniaturas de YouTube son 4:3 con bandas negras: al
              // recortar a cuadrado quedan como una carátula.
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Portada generada: degradado con un color estable por canción, para que
/// la biblioteca sin conexión no sea una pared de iconos grises.
class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (seed.hashCode % 360).abs().toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.22).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.42,
        color: Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}
