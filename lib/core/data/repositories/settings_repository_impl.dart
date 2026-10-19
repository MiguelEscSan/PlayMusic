import 'package:koda/core/data/repositories/guard.dart';
import 'package:koda/core/domain/repositories/i_settings_repository.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/core/settings/settings_dao.dart';

/// [ISettingsRepository] sobre la tabla `settings` ([SettingsDao]). Aquí
/// viven las claves ([SettingsKeys]) y los valores por defecto.
class SettingsRepositoryImpl implements ISettingsRepository {
  SettingsRepositoryImpl(this._dao);

  final SettingsDao _dao;

  @override
  Future<Result<bool>> getRadioEnabled() =>
      guard(() => _dao.getBool(SettingsKeys.radioEnabled, fallback: true));

  @override
  Future<Result<Unit>> setRadioEnabled(bool enabled) =>
      _write(() => _dao.setBool(SettingsKeys.radioEnabled, enabled));

  @override
  Future<Result<bool>> getDownloadOnlyWifi() =>
      guard(() => _dao.getBool(SettingsKeys.downloadOnlyWifi, fallback: false));

  @override
  Future<Result<Unit>> setDownloadOnlyWifi(bool enabled) =>
      _write(() => _dao.setBool(SettingsKeys.downloadOnlyWifi, enabled));

  @override
  Future<Result<String?>> getLikedPlaylistId() =>
      guard(() => _dao.get(SettingsKeys.likedPlaylistId));

  @override
  Future<Result<Unit>> setLikedPlaylistId(String id) =>
      _write(() => _dao.set(SettingsKeys.likedPlaylistId, id));

  Future<Result<Unit>> _write(Future<void> Function() action) =>
      guard(() async {
        await action();
        return unit;
      });
}
