import 'package:koda/core/error/result.dart';

/// Búsquedas recientes. Nunca lanza: un fallo de la BD llega como `Err`.
abstract interface class ISearchHistoryRepository {
  /// La última primero.
  Future<Result<List<String>>> recent();

  /// Apunta [query] (sin espacios sobrantes) como la más reciente. Una
  /// búsqueda vacía se ignora.
  Future<Result<Unit>> record(String query);

  Future<Result<Unit>> remove(String query);

  Future<Result<Unit>> clear();
}
