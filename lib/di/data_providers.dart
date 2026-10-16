import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/repositories/playlist_repository_impl.dart';
import '../core/data/repositories/song_repository_impl.dart';
import '../core/database/playlist_dao.dart';
import '../core/database/song_dao.dart';
import '../core/domain/repositories/i_playlist_repository.dart';
import '../core/domain/repositories/i_song_repository.dart';
import '../core/settings/settings_dao.dart';
import '../features/history/data/history_dao.dart';
import '../features/search/data/search_history_dao.dart';

// Regla de instancias: todo lo que crea `bootstrap()` se inyecta en `main()`
// con `overrideWithValue` (ver `appOverrides`), así que la app entera usa
// esas mismas instancias. Los cuerpos por defecto que derivan un provider de
// otro solo se usan cuando no hay override: en los tests, que sobrescriben
// los DAOs y obtienen repositorios construidos sobre ellos.

/// DAOs de la BD local. Se sobrescriben en `main()` con las instancias de
/// `bootstrap()`. La UI no los usa: pasa por los repositorios o notifiers.
final songDaoProvider = Provider<SongDao>(
  (ref) => throw UnimplementedError('songDaoProvider se define en main()'),
);

final playlistDaoProvider = Provider<PlaylistDao>(
  (ref) => throw UnimplementedError('playlistDaoProvider se define en main()'),
);

final historyDaoProvider = Provider<HistoryDao>(
  (ref) => throw UnimplementedError('historyDaoProvider se define en main()'),
);

final searchHistoryDaoProvider = Provider<SearchHistoryDao>(
  (ref) =>
      throw UnimplementedError('searchHistoryDaoProvider se define en main()'),
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => throw UnimplementedError('settingsDaoProvider se define en main()'),
);

/// Repositorios de dominio. En la app se sobrescriben con los de
/// `bootstrap()`; sin override (tests) se derivan del provider del DAO, así
/// que basta con sobrescribir el DAO para que el repositorio lo use.
final songRepositoryProvider = Provider<ISongRepository>(
  (ref) => SongRepositoryImpl(ref.watch(songDaoProvider)),
);

final playlistRepositoryProvider = Provider<IPlaylistRepository>(
  (ref) => PlaylistRepositoryImpl(ref.watch(playlistDaoProvider)),
);
