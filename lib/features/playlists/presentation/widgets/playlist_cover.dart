import 'package:flutter/material.dart';

import '../../../../core/models/playlist.dart';
import '../../../../shared/widgets/artwork_image.dart';

/// Portada de una playlist: imagen única o mosaico 2×2 de carátulas, según
/// [Playlist.coverUrls]. Sin imágenes, la portada generada a partir del
/// nombre.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover(
    this.playlist, {
    super.key,
    this.size = 48,
    this.radius = 6,
  });

  final Playlist playlist;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final urls = playlist.coverUrls;
    if (urls.length < 4) {
      return ArtworkImage(
        url: urls.firstOrNull,
        seed: playlist.name,
        size: size,
        radius: radius,
      );
    }
    final tile = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final url in urls)
              ArtworkImage(url: url, seed: url, size: tile, radius: 0),
          ],
        ),
      ),
    );
  }
}
