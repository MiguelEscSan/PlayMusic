import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';

/// Mantiene la playlist "Me encanta" igual que los "me gusta". Nunca lanza:
/// todo error se devuelve como `Err`.
abstract interface class ILikedPlaylistSync {
  /// Añade o quita [song] de "Me encanta" según su `isLiked` (ya guardado).
  Future<Result<Unit>> sync(Song song);
}

/// El "me gusta" se guardó ([song] es la canción ya actualizada), pero la
/// playlist "Me encanta" no se pudo sincronizar. [cause] es el fallo de la
/// sincronización.
final class LikedPlaylistSyncFailure extends SyncFailure {
  const LikedPlaylistSyncFailure(this.song, {required Failure cause})
    : super(
        'El "me gusta" se guardó, pero no se pudo actualizar "Me encanta"',
        cause: cause,
      );

  final Song song;
}
