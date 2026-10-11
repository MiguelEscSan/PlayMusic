import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playlist.dart';
import '../data/playlist_dao.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final playlistDaoProvider = Provider<PlaylistDao>(
  (ref) => throw UnimplementedError('playlistDaoProvider se define en main()'),
);

final playlistsProvider = StreamProvider<List<Playlist>>((ref) async* {
  final dao = ref.watch(playlistDaoProvider);
  yield await dao.all();
  await for (final _ in dao.changes) {
    yield await dao.all();
  }
});

/// Una playlist con sus canciones; null si se ha borrado.
final playlistProvider = StreamProvider.family<Playlist?, String>((
  ref,
  id,
) async* {
  final dao = ref.watch(playlistDaoProvider);
  yield await dao.findById(id);
  await for (final _ in dao.changes) {
    yield await dao.findById(id);
  }
});
