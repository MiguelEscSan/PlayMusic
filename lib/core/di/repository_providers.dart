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
import '../error/result.dart';

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

/// Valor de un `Ok`; un `Err` lanza su `Failure` tipado.
///
/// Transitorio: lo usan los `StreamProvider` que aún se refrescan con los
/// `changes` de los DAOs, para que un fallo llegue a la UI como `AsyncError`.
/// En la fase 3 los notifiers tratarán el `Err` explícitamente.
T unwrapOrThrow<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw failure,
};
