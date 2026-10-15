import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/song.dart';
import '../data/history_dao.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final historyDaoProvider = Provider<HistoryDao>(
  (ref) => throw UnimplementedError('historyDaoProvider se define en main()'),
);

/// Lo escuchado recientemente; se vuelve a consultar con cada cambio.
final recentSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(historyDaoProvider);
  yield await dao.recent();
  await for (final _ in dao.changes) {
    yield await dao.recent();
  }
});
