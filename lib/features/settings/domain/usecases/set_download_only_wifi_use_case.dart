import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Activa o desactiva "Descargar solo con wifi".
final class SetDownloadOnlyWifiUseCase {
  const SetDownloadOnlyWifiUseCase(this._settings);

  final ISettingsRepository _settings;

  Future<Result<Unit>> call(bool enabled) =>
      _settings.setDownloadOnlyWifi(enabled);
}
