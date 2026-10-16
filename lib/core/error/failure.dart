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

/// El dato de entrada no es válido (p. ej. un enlace mal formado).
///
/// No es `final`: cada feature puede concretarlo (p. ej. un enlace de
/// playlist no válido) para que la UI elija su mensaje.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

/// Error de red al hablar con un servicio remoto (YouTube, etc.).
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

/// Error del almacenamiento de archivos (copiar, borrar, renombrar).
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

/// El cambio principal se guardó, pero una copia que depende de él no se
/// pudo actualizar (p. ej. el "me gusta" sí, la playlist "Me encanta" no).
///
/// No es `final`: cada feature lo concreta con lo que sí se guardó.
class SyncFailure extends Failure {
  const SyncFailure(super.message, {super.cause, super.stackTrace});
}

/// El reproductor de audio no pudo hacer la acción pedida (reproducir,
/// saltar, cambiar la cola...).
final class PlaybackFailure extends Failure {
  const PlaybackFailure(super.message, {super.cause, super.stackTrace});
}

/// Cualquier error no previsto por los demás subtipos.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
