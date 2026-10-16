import 'package:sponify/core/domain/guard.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';

/// Ejecuta una acción del reproductor y devuelve `Ok(unit)`; si lanza,
/// `Err(PlaybackFailure)` con [message]. Así ningún caso de uso del
/// reproductor lanza.
Future<Result<Unit>> guardPlayback(
  Future<void> Function() action,
  String message,
) => guard(() async {
  await action();
  return unit;
}, onError: (e, st) => PlaybackFailure(message, cause: e, stackTrace: st));
