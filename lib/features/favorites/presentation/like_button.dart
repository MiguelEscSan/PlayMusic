import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/song.dart';
import '../../../shared/song_actions.dart';
import 'favorites_providers.dart';

/// Corazón que marca o desmarca "me gusta"; relleno cuando ya es favorita.
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.song, this.size = 28});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(isLikedProvider(song));
    return IconButton(
      tooltip: isLiked ? 'Quitar de Me gusta' : 'Me gusta',
      iconSize: size,
      onPressed: () => ref.read(songActionsProvider).toggleLike(song),
      icon: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isLiked ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
