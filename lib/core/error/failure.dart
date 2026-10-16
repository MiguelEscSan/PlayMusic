/// Fallo tipado que la capa de dominio devuelve dentro de un `Err`.
///
/// Es `sealed`: quien consuma un [Failure] puede hacer un `switch`
/// exhaustivo sobre sus subtipos sin rama por defecto.
sealed class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// Descripción legible del fallo (para logs; la UI decide su propio texto).
  final String message;

  /// Excepción original que provocó el fallo, si la hubo.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() {
    final base = '$runtimeType: $message';
    return cause == null ? base : '$base (cause: $cause)';
  }
}

/// Error de la base de datos local (sqflite) al leer o escribir.
final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause, super.stackTrace});
}

/// La entidad pedida no existe (p. ej. una playlist borrada).
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// Cualquier error no previsto por los demás subtipos.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
