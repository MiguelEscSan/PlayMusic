import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../shared/song_actions.dart';
import '../../../shared/widgets/dialogs.dart';
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
      onPressed: () async {
        final result = await ref.read(songActionsProvider).toggleLike(song);
        if (result.isErr && context.mounted) {
          showSnack(context, 'No se pudo actualizar "Me gusta"');
        }
      },
      icon: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isLiked ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
