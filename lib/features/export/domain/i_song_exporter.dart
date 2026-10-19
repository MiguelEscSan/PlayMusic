import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';

/// Copia una canción descargada a la carpeta pública de Música del móvil,
/// para que otras apps (reproductores, gestores de archivos) la vean.
abstract interface class ISongExporter {
  /// `Ok` con una descripción legible de dónde ha quedado el archivo;
  /// `Err(SongExportFailure)` si no se puede exportar. Nunca lanza.
  Future<Result<String>> export(Song song);
}

enum SongExportError {
  notDownloaded,
  fileNotFound,
  permissionDenied,
  unsupported,
  failed,
}

/// No se pudo exportar la canción. [error] dice por qué; [message] es el
/// texto para el usuario.
final class SongExportFailure extends ExportFailure {
  SongExportFailure(this.error, {this.details, super.cause, super.stackTrace})
    : super(_userMessage(error));

  final SongExportError error;

  /// Mensaje técnico de la plataforma (solo para depurar).
  final String? details;

  static String _userMessage(SongExportError error) => switch (error) {
    SongExportError.notDownloaded => 'La canción no está descargada',
    SongExportError.fileNotFound => 'No se encuentra el archivo descargado',
    SongExportError.permissionDenied =>
      'Sin permiso para guardar en la carpeta Música',
    SongExportError.unsupported => 'Exportar no está disponible aquí',
    SongExportError.failed => 'No se pudo exportar la canción',
  };

  @override
  String toString() => 'SongExportFailure($error, $details)';
}
