import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

/// Ejecuta [action] y convierte su resultado en un [Result]: el valor va en
/// [Ok]; un [DatabaseException] de sqflite se traduce a [DatabaseFailure] y
/// cualquier otra [Exception] a [UnexpectedFailure], conservando la causa y
/// la traza.
///
/// Solo captura [Exception]: los [Error] (fallos de programación) se dejan
/// propagar a propósito para que no queden ocultos tras un `Err`.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Ok(await action());
  } on DatabaseException catch (e, st) {
    return Err(DatabaseFailure(e.toString(), cause: e, stackTrace: st));
  } on Exception catch (e, st) {
    return Err(UnexpectedFailure(e.toString(), cause: e, stackTrace: st));
  }
}
