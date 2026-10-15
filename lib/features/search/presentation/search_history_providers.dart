import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_history_dao.dart';

/// Se sobrescribe en `main()` con la instancia de `bootstrap()`.
final searchHistoryDaoProvider = Provider<SearchHistoryDao>(
  (ref) =>
      throw UnimplementedError('searchHistoryDaoProvider se define en main()'),
);

/// Búsquedas recientes; se vuelven a consultar con cada cambio.
final recentSearchesProvider = StreamProvider<List<String>>((ref) async* {
  final dao = ref.watch(searchHistoryDaoProvider);
  yield await dao.recent();
  await for (final _ in dao.changes) {
    yield await dao.recent();
  }
});
