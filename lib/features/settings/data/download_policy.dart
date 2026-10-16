import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/domain/repositories/i_settings_repository.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

/// Comprobación para `DownloadManager.canDownload`: si el ajuste "Descargar
/// solo con wifi" está activo, solo deja empezar con wifi o ethernet. Si el
/// ajuste no se puede leer se trata como desactivado (mejor descargar que
/// quedarse colgado).
Future<bool> Function() downloadPolicy(
  ISettingsRepository settings, {
  ConnectivityCheck? connectivity,
}) {
  final check = connectivity ?? Connectivity().checkConnectivity;
  return () async {
    final onlyWifi =
        (await settings.getDownloadOnlyWifi()).valueOrNull ?? false;
    if (!onlyWifi) return true;
    final results = await check();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  };
}
