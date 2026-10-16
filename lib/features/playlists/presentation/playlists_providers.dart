import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeExplode;

import '../../../core/di/repository_providers.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../data/playlist_cover_service.dart';
import '../data/playlist_dao.dart';
import '../data/youtube_playlist_importer.dart';

export 'playlist_detail_notifier.dart';
export 'playlists_notifier.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`. Solo lo usa
/// `playlistRepositoryProvider`: la UI pasa por los notifiers.
final playlistDaoProvider = Provider<PlaylistDao>(
  (ref) => throw UnimplementedError('playlistDaoProvider se define en main()'),
);

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final playlistCoverServiceProvider = Provider<PlaylistCoverService>(
  (ref) => throw UnimplementedError(
    'playlistCoverServiceProvider se define en main()',
  ),
);

/// Importador de playlists de YouTube. El cliente de YouTube se crea al
/// importar por primera vez (construir la pantalla no toca la red) y se
/// cierra al desechar el provider.
final youtubePlaylistImporterProvider = Provider<YoutubePlaylistImporter>((
  ref,
) {
  YoutubeExplode? yt;
  ref.onDispose(() => yt?.close());
  return YoutubePlaylistImporter.youtube(
    ref.watch(playlistRepositoryProvider),
    () => yt ??= YoutubeExplode(),
  );
});

/// Reconstruye el provider de [ref] cuando cambia el conjunto de canciones
/// descargadas: una descarga que termina o se borra cambia cómo se pintan
/// sus playlists (icono, "Descargada", contador).
///
/// Se observa una firma ordenada de las claves, no el `Set`: cada recarga
/// de las descargas crea un `Set` nuevo aunque el contenido sea el mismo, y
/// eso no debe recargar las playlists.
void rebuildOnDownloadsChange(Ref ref) =>
    ref.watch(downloadedKeysProvider.select(_signature));

String _signature(Set<String> keys) => (keys.toList()..sort()).join('\n');
