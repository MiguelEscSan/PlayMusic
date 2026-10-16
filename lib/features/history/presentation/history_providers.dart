import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entities/song.dart';
import '../../../di/providers.dart';

/// Más escuchadas de los últimos 30 días; se vuelve a consultar con cada cambio.
/// El historial no tiene repositorio: se mapean aquí los DTO a entidades.
final topSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(historyDaoProvider);
  Future<List<Song>> load() async => [
    for (final model in await dao.topSongs()) model.toEntity(),
  ];
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
  }
});

/// Lo escuchado recientemente; se vuelve a consultar con cada cambio.
final recentSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final dao = ref.watch(historyDaoProvider);
  Future<List<Song>> load() async => [
    for (final model in await dao.recent()) model.toEntity(),
  ];
  yield await load();
  await for (final _ in dao.changes) {
    yield await load();
  }
});
