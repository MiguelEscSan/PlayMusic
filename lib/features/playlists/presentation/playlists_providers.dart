import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloads/presentation/downloads_providers.dart';

export 'playlist_detail_notifier.dart';
export 'playlists_notifier.dart';

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
