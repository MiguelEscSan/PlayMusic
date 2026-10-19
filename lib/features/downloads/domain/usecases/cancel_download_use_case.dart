import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/i_download_service.dart';

/// Cancela una descarga en cola o en curso. Un error al borrar el archivo
/// parcial llega como `Err(StorageFailure)`.
final class CancelDownloadUseCase {
  const CancelDownloadUseCase(this._downloads);

  final IDownloadService _downloads;

  Future<Result<Unit>> call(Song song) => guard(
    () async {
      await _downloads.cancel(song);
      return unit;
    },
    onError: (e, st) => StorageFailure(
      'No se pudo cancelar la descarga',
      cause: e,
      stackTrace: st,
    ),
  );
}
