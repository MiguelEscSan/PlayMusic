import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/downloads/domain/i_download_service.dart';

/// Borra todas las descargas. Se detiene en el primer fallo y lo devuelve.
final class DeleteAllDownloadsUseCase {
  const DeleteAllDownloadsUseCase(this._downloads);

  final IDownloadService _downloads;

  Future<Result<Unit>> call() => guardResult(
    _downloads.deleteAll,
    onError: (e, st) => StorageFailure(
      'No se pudieron borrar las descargas',
      cause: e,
      stackTrace: st,
    ),
  );
}
