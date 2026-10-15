import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/settings/settings_dao.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

/// Comprobación para `DownloadManager.canDownload`: si el ajuste "Descargar
/// solo con wifi" está activo, solo deja empezar con wifi o ethernet.
Future<bool> Function() downloadPolicy(
  SettingsDao settings, {
  ConnectivityCheck? connectivity,
}) {
  final check = connectivity ?? Connectivity().checkConnectivity;
  return () async {
    final onlyWifi = await settings.getBool(
      SettingsKeys.downloadOnlyWifi,
      fallback: false,
    );
    if (!onlyWifi) return true;
    final results = await check();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  };
}
