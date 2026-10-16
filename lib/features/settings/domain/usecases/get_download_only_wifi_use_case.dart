import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Si las descargas solo empiezan con wifi.
final class GetDownloadOnlyWifiUseCase {
  const GetDownloadOnlyWifiUseCase(this._settings);

  final ISettingsRepository _settings;

  Future<Result<bool>> call() => _settings.getDownloadOnlyWifi();
}
