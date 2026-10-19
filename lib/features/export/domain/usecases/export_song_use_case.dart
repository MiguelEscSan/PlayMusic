import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/export/domain/i_song_exporter.dart';

/// Copia el archivo descargado de una canción a la carpeta pública de
/// Música. `Err(SongExportFailure)` conserva el tipo de error para que la
/// UI muestre su mensaje.
final class ExportSongUseCase {
  const ExportSongUseCase(this._exporter);

  final ISongExporter _exporter;

  Future<Result<String>> call(Song song) => guardResult(
    () => _exporter.export(song),
    onError: (e, st) => SongExportFailure(
      SongExportError.failed,
      details: '$e',
      cause: e,
      stackTrace: st,
    ),
  );
}
