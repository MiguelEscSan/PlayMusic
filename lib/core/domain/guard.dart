import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';

/// Traduce una excepción en el [Failure] que devuelve el caso de uso.
typedef FailureMapper = Failure Function(Object error, StackTrace stackTrace);

/// Ejecuta [action] y devuelve su valor como `Ok`; si lanza, devuelve
/// `Err` con el fallo que da [onError]. Para casos de uso sobre servicios
/// que pueden lanzar (archivos, red): el caso de uso nunca lanza.
Future<Result<T>> guard<T>(
  Future<T> Function() action, {
  required FailureMapper onError,
}) async {
  try {
    return Ok(await action());
  } catch (e, st) {
    return Err(onError(e, st));
  }
}

/// Como [guard], para acciones que ya devuelven un `Result`.
Future<Result<T>> guardResult<T>(
  Future<Result<T>> Function() action, {
  required FailureMapper onError,
}) async {
  try {
    return await action();
  } catch (e, st) {
    return Err(onError(e, st));
  }
}
