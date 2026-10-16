import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Activa o desactiva la radio automática.
final class SetRadioEnabledUseCase {
  const SetRadioEnabledUseCase(this._settings);

  final ISettingsRepository _settings;

  Future<Result<Unit>> call(bool enabled) => _settings.setRadioEnabled(enabled);
}
