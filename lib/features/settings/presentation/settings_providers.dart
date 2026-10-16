import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_dao.dart';
import '../../../di/providers.dart';
import '../../downloads/presentation/downloads_providers.dart';

/// Un ajuste booleano que se vuelve a leer con cada cambio en `settings`.
StreamProvider<bool> _boolSetting(String key, {required bool fallback}) =>
    StreamProvider<bool>((ref) async* {
      final dao = ref.watch(settingsDaoProvider);
      yield await dao.getBool(key, fallback: fallback);
      await for (final _ in dao.changes) {
        yield await dao.getBool(key, fallback: fallback);
      }
    });

/// Radio automática al acabar la cola (por defecto activada).
final radioEnabledProvider = _boolSetting(
  SettingsKeys.radioEnabled,
  fallback: true,
);

/// Descargar solo con wifi (por defecto desactivado).
final downloadOnlyWifiProvider = _boolSetting(
  SettingsKeys.downloadOnlyWifi,
  fallback: false,
);

/// Espacio ocupado por las descargas: bytes y número de canciones.
typedef StorageUsage = ({int bytes, int songs});

/// `null` mientras carga (o si las descargas no están disponibles).
final storageUsageProvider = Provider<StorageUsage?>((ref) {
  final songs = ref.watch(downloadedSongsProvider).value;
  if (songs == null) return null;
  final bytes = songs.fold<int>(0, (sum, s) => sum + (s.fileSizeBytes ?? 0));
  return (bytes: bytes, songs: songs.length);
});
