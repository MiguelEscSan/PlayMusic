import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/playlists/domain/i_playlist_importer.dart';

/// Importa una playlist de YouTube a partir de su enlace o su id, avisando
/// del progreso con `onProgress`. Los fallos llegan tipados (ver
/// [IPlaylistImporter]); una excepción inesperada del importador llega como
/// `Err(NetworkFailure)`.
final class ImportYoutubePlaylistUseCase {
  const ImportYoutubePlaylistUseCase(this._importer);

  final IPlaylistImporter _importer;

  Future<Result<ImportResult>> call(
    String link, {
    ImportProgress? onProgress,
  }) => guardResult(
    () => _importer.importFromUrl(link, onProgress: onProgress),
    onError: (e, st) => NetworkFailure(
      'No se pudo importar la playlist',
      cause: e,
      stackTrace: st,
    ),
  );
}
