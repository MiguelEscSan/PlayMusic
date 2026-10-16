import 'package:sponify/core/error/failure.dart';

/// Resultado de una operación que puede fallar: [Ok] con el valor o [Err]
/// con un [Failure]. Sustituye a las excepciones en la frontera del dominio.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// El valor si es [Ok]; `null` si es [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// El fallo si es [Err]; `null` si es [Ok].
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Reduce el resultado a un único valor tratando ambos casos.
  R fold<R>(R Function(Failure failure) onErr, R Function(T value) onOk) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  /// Transforma el valor de un [Ok]; un [Err] se propaga sin cambios.
  Result<R> map<R>(R Function(T value) f) => switch (this) {
    Ok<T>(:final value) => Ok<R>(f(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Valor único para operaciones sin resultado útil (`Result<Unit>`).
final class Unit {
  const Unit._();

  @override
  String toString() => 'unit';
}

const unit = Unit._();
