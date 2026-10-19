import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/search/domain/suggestion_source.dart';

/// Sugerencias para el texto que se está escribiendo. Un fallo (sin red,
/// respuesta rara…) llega como `Err(NetworkFailure)`.
final class GetSuggestionsUseCase {
  const GetSuggestionsUseCase(this._source);

  final SuggestionSource _source;

  Future<Result<List<String>>> call(String query) => guard(
    () => _source.suggestions(query),
    onError: (e, st) => NetworkFailure(
      'No se pudieron cargar las sugerencias',
      cause: e,
      stackTrace: st,
    ),
  );
}
