import 'package:sponify/core/error/result.dart';

/// Ajustes de la app, con un método tipado por ajuste: las claves y el
/// formato en que se guardan son cosa de la capa de datos.
///
/// Nunca lanza: un fallo del almacenamiento llega como `Err`.
abstract interface class ISettingsRepository {
  /// Radio automática al acabar la cola (por defecto activada).
  Future<Result<bool>> getRadioEnabled();

  Future<Result<Unit>> setRadioEnabled(bool enabled);

  /// Descargar solo con wifi (por defecto desactivado).
  Future<Result<bool>> getDownloadOnlyWifi();

  Future<Result<Unit>> setDownloadOnlyWifi(bool enabled);

  /// Id de la playlist "Me encanta"; `null` si aún no se ha creado.
  Future<Result<String?>> getLikedPlaylistId();

  Future<Result<Unit>> setLikedPlaylistId(String id);
}
