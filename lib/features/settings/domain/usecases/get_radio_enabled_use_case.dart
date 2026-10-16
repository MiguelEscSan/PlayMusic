import 'package:sponify/core/domain/repositories/i_settings_repository.dart';
import 'package:sponify/core/error/result.dart';

/// Si la radio automática sigue al acabar la cola.
final class GetRadioEnabledUseCase {
  const GetRadioEnabledUseCase(this._settings);

  final ISettingsRepository _settings;

  Future<Result<bool>> call() => _settings.getRadioEnabled();
}
