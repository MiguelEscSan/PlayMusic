import 'package:flutter_riverpod/misc.dart' show Override;

import '../bootstrap.dart';
import 'data_providers.dart';
import 'service_providers.dart';

/// Inyecta en el `ProviderScope` las instancias que crea `bootstrap()`, para
/// que la app y el arranque compartan exactamente los mismos objetos.
List<Override> appOverrides(AppDependencies deps) => [
  audioPlayerServiceProvider.overrideWithValue(deps.audio),
  songDaoProvider.overrideWithValue(deps.songDao),
  playlistDaoProvider.overrideWithValue(deps.playlistDao),
  historyDaoProvider.overrideWithValue(deps.historyDao),
  settingsDaoProvider.overrideWithValue(deps.settings),
  searchHistoryDaoProvider.overrideWithValue(deps.searchHistory),
  songRepositoryProvider.overrideWithValue(deps.songRepository),
  playlistRepositoryProvider.overrideWithValue(deps.playlistRepository),
  likedPlaylistProvider.overrideWithValue(deps.likedPlaylist),
  playlistCoverServiceProvider.overrideWithValue(deps.playlistCovers),
  downloadServiceProvider.overrideWithValue(deps.downloads),
];
