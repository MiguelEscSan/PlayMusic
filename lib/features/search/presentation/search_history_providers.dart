import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';

/// Búsquedas recientes; se vuelven a consultar con cada cambio.
final recentSearchesProvider = StreamProvider<List<String>>((ref) async* {
  final dao = ref.watch(searchHistoryDaoProvider);
  yield await dao.recent();
  await for (final _ in dao.changes) {
    yield await dao.recent();
  }
});
