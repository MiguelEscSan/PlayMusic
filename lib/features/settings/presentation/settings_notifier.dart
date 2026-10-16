import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../di/providers.dart';
import '../../../shared/no_automatic_retry.dart';

/// Ajustes que muestra la pantalla de Ajustes.
class AppSettings {
  const AppSettings({this.radioEnabled = true, this.downloadOnlyWifi = false});

  /// Valores por defecto (los que se ven mientras carga).
  static const defaults = AppSettings();

  final bool radioEnabled;
  final bool downloadOnlyWifi;

  AppSettings copyWith({bool? radioEnabled, bool? downloadOnlyWifi}) =>
      AppSettings(
        radioEnabled: radioEnabled ?? this.radioEnabled,
        downloadOnlyWifi: downloadOnlyWifi ?? this.downloadOnlyWifi,
      );
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
  retry: noAutomaticRetry,
);

/// Dueño de los ajustes en pantalla. Cada setter cambia el estado al
/// momento y lo guarda; si guardar falla, vuelve al valor anterior y
/// devuelve el `Err` para que la UI avise.
///
/// Un `Err` al cargar se lanza como su `Failure` tipado: la UI lo recibe
/// como `AsyncError`.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final radio = await ref.watch(getRadioEnabledUseCaseProvider)();
    final onlyWifi = await ref.watch(getDownloadOnlyWifiUseCaseProvider)();
    return switch ((radio, onlyWifi)) {
      (Ok(value: final r), Ok(value: final w)) => AppSettings(
        radioEnabled: r,
        downloadOnlyWifi: w,
      ),
      (Err(:final failure), _) || (_, Err(:final failure)) => throw failure,
    };
  }

  Future<Result<Unit>> setRadioEnabled(bool enabled) => _update(
    (s) => s.copyWith(radioEnabled: enabled),
    () => ref.read(setRadioEnabledUseCaseProvider)(enabled),
  );

  Future<Result<Unit>> setDownloadOnlyWifi(bool enabled) => _update(
    (s) => s.copyWith(downloadOnlyWifi: enabled),
    () => ref.read(setDownloadOnlyWifiUseCaseProvider)(enabled),
  );

  Future<Result<Unit>> _update(
    AppSettings Function(AppSettings current) change,
    Future<Result<Unit>> Function() persist,
  ) async {
    final previous = state.value ?? AppSettings.defaults;
    state = AsyncData(change(previous));
    final result = await persist();
    if (result.isErr && ref.mounted) state = AsyncData(previous);
    return result;
  }
}
