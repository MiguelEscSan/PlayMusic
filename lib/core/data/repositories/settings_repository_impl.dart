import 'dart:convert';

import 'package:koda/core/data/repositories/guard.dart';
import 'package:koda/core/domain/entities/last_playback.dart';
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

  @override
  Future<Result<LastPlayback?>> getLastPlayback() => guard(() async {
    final raw = await _dao.get(SettingsKeys.lastPlayback);
    if (raw == null) return null;
    try {
      return _decodeLastPlayback(raw);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  });

  @override
  Future<Result<Unit>> setLastPlayback(LastPlayback playback) => _write(
    () => _dao.set(SettingsKeys.lastPlayback, _encodeLastPlayback(playback)),
  );

  static String _encodeLastPlayback(LastPlayback playback) => jsonEncode({
    'songIds': playback.songIds,
    'index': playback.index,
    'positionMs': playback.position.inMilliseconds,
  });

  static LastPlayback _decodeLastPlayback(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return LastPlayback(
      songIds: (json['songIds'] as List<dynamic>).cast<String>(),
      index: json['index'] as int,
      position: Duration(milliseconds: json['positionMs'] as int),
    );
  }

  Future<Result<Unit>> _write(Future<void> Function() action) =>
      guard(() async {
        await action();
        return unit;
      });
}
