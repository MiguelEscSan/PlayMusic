import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/presentation/downloads_providers.dart';
import '../../features/favorites/domain/usecases/toggle_favorite_use_case.dart';
import '../../features/playlists/domain/usecases/add_song_to_playlist_use_case.dart';
import '../../features/playlists/domain/usecases/remove_song_from_playlist_use_case.dart';
import '../../features/playlists/presentation/playlists_providers.dart';
import '../data/repositories/playlist_repository_impl.dart';
import '../data/repositories/song_repository_impl.dart';
import '../domain/repositories/i_playlist_repository.dart';
import '../domain/repositories/i_song_repository.dart';

/// Repositorios de dominio. Se derivan de los providers de los DAOs, así
/// que basta con sobrescribir el DAO (en `main()` o en un test) para que el
/// repositorio use esa instancia.
final songRepositoryProvider = Provider<ISongRepository>(
  (ref) => SongRepositoryImpl(ref.watch(songDaoProvider)),
);

final playlistRepositoryProvider = Provider<IPlaylistRepository>(
  (ref) => PlaylistRepositoryImpl(ref.watch(playlistDaoProvider)),
);

final toggleFavoriteUseCaseProvider = Provider<ToggleFavoriteUseCase>(
  (ref) => ToggleFavoriteUseCase(ref.watch(songRepositoryProvider)),
);

final addSongToPlaylistUseCaseProvider = Provider<AddSongToPlaylistUseCase>(
  (ref) => AddSongToPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);

final removeSongFromPlaylistUseCaseProvider =
    Provider<RemoveSongFromPlaylistUseCase>(
      (ref) =>
          RemoveSongFromPlaylistUseCase(ref.watch(playlistRepositoryProvider)),
    );

/// `retry` de los notifiers que cargan de un repositorio y lanzan su
/// `Failure` tipado: un fallo de la BD local no es transitorio, así que se
/// muestra con su botón de reintentar en vez de reintentarlo en segundo
/// plano (y dejar la pantalla cargando mientras tanto).
Duration? noAutomaticRetry(int retryCount, Object error) => null;
