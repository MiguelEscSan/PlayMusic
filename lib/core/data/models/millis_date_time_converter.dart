import 'package:json_annotation/json_annotation.dart';

/// SQLite guarda las fechas como milisegundos desde epoch.
class MillisDateTimeConverter implements JsonConverter<DateTime, int> {
  const MillisDateTimeConverter();

  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int toJson(DateTime object) => object.millisecondsSinceEpoch;
}

/// Igual que [MillisDateTimeConverter] para columnas que admiten NULL.
class NullableMillisDateTimeConverter
    implements JsonConverter<DateTime?, int?> {
  const NullableMillisDateTimeConverter();

  @override
  DateTime? fromJson(int? json) =>
      json == null ? null : DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int? toJson(DateTime? object) => object?.millisecondsSinceEpoch;
}
