// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SongModel {

 String get id; String get title; String get artist;@JsonKey(name: 'duration_ms') int get durationMs; SongSource get source;@JsonKey(name: 'source_id') String get sourceId; String? get album;@JsonKey(name: 'artwork_url') String? get artworkUrl;/// Última URL de streaming conocida. Puede estar caducada: tratarla como
/// caché, nunca como fuente de verdad.
@JsonKey(name: 'stream_url') String? get streamUrl;/// Ruta absoluta del archivo descargado. `null` = no descargada.
@JsonKey(name: 'local_path') String? get localPath;/// Tamaño en disco del archivo descargado (para la vista "Descargas").
@JsonKey(name: 'file_size_bytes') int? get fileSizeBytes;@JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter() DateTime? get downloadedAt;/// Estado transitorio de UI (0.0 – 1.0). NO se persiste en la BD; la
/// fuente de verdad del progreso es el stream del gestor de descargas.
@JsonKey(includeFromJson: false, includeToJson: false) double? get downloadProgress;/// Cuándo se marcó "me gusta". `null` = no está en Favoritos. Se lee de
/// la BD pero NO se escribe en [toJson]: así `SongDao.upsert` nunca borra
/// un like; solo lo escribe `SongDao.setLiked`.
@JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter() DateTime? get likedAt;
/// Create a copy of SongModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SongModelCopyWith<SongModel> get copyWith => _$SongModelCopyWithImpl<SongModel>(this as SongModel, _$identity);

  /// Serializes this SongModel to a JSON map.
  Map<String, dynamic> toJson();






}

/// @nodoc
abstract mixin class $SongModelCopyWith<$Res>  {
  factory $SongModelCopyWith(SongModel value, $Res Function(SongModel) _then) = _$SongModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String artist,@JsonKey(name: 'duration_ms') int durationMs, SongSource source,@JsonKey(name: 'source_id') String sourceId, String? album,@JsonKey(name: 'artwork_url') String? artworkUrl,@JsonKey(name: 'stream_url') String? streamUrl,@JsonKey(name: 'local_path') String? localPath,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes,@JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter() DateTime? downloadedAt,@JsonKey(includeFromJson: false, includeToJson: false) double? downloadProgress,@JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter() DateTime? likedAt
});




}
/// @nodoc
class _$SongModelCopyWithImpl<$Res>
    implements $SongModelCopyWith<$Res> {
  _$SongModelCopyWithImpl(this._self, this._then);

  final SongModel _self;
  final $Res Function(SongModel) _then;

/// Create a copy of SongModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? artist = null,Object? durationMs = null,Object? source = null,Object? sourceId = null,Object? album = freezed,Object? artworkUrl = freezed,Object? streamUrl = freezed,Object? localPath = freezed,Object? fileSizeBytes = freezed,Object? downloadedAt = freezed,Object? downloadProgress = freezed,Object? likedAt = freezed,}) {
  return _then(SongModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SongSource,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,streamUrl: freezed == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,downloadProgress: freezed == downloadProgress ? _self.downloadProgress : downloadProgress // ignore: cast_nullable_to_non_nullable
as double?,likedAt: freezed == likedAt ? _self.likedAt : likedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SongModel].
extension SongModelPatterns on SongModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SongModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SongModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SongModel value)  $default,){
final _that = this;
switch (_that) {
case _SongModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SongModel value)?  $default,){
final _that = this;
switch (_that) {
case _SongModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String artist, @JsonKey(name: 'duration_ms')  int durationMs,  SongSource source, @JsonKey(name: 'source_id')  String sourceId,  String? album, @JsonKey(name: 'artwork_url')  String? artworkUrl, @JsonKey(name: 'stream_url')  String? streamUrl, @JsonKey(name: 'local_path')  String? localPath, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter()  DateTime? downloadedAt, @JsonKey(includeFromJson: false, includeToJson: false)  double? downloadProgress, @JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter()  DateTime? likedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SongModel() when $default != null:
return $default(_that.id,_that.title,_that.artist,_that.durationMs,_that.source,_that.sourceId,_that.album,_that.artworkUrl,_that.streamUrl,_that.localPath,_that.fileSizeBytes,_that.downloadedAt,_that.downloadProgress,_that.likedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String artist, @JsonKey(name: 'duration_ms')  int durationMs,  SongSource source, @JsonKey(name: 'source_id')  String sourceId,  String? album, @JsonKey(name: 'artwork_url')  String? artworkUrl, @JsonKey(name: 'stream_url')  String? streamUrl, @JsonKey(name: 'local_path')  String? localPath, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter()  DateTime? downloadedAt, @JsonKey(includeFromJson: false, includeToJson: false)  double? downloadProgress, @JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter()  DateTime? likedAt)  $default,) {final _that = this;
switch (_that) {
case _SongModel():
return $default(_that.id,_that.title,_that.artist,_that.durationMs,_that.source,_that.sourceId,_that.album,_that.artworkUrl,_that.streamUrl,_that.localPath,_that.fileSizeBytes,_that.downloadedAt,_that.downloadProgress,_that.likedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String artist, @JsonKey(name: 'duration_ms')  int durationMs,  SongSource source, @JsonKey(name: 'source_id')  String sourceId,  String? album, @JsonKey(name: 'artwork_url')  String? artworkUrl, @JsonKey(name: 'stream_url')  String? streamUrl, @JsonKey(name: 'local_path')  String? localPath, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter()  DateTime? downloadedAt, @JsonKey(includeFromJson: false, includeToJson: false)  double? downloadProgress, @JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter()  DateTime? likedAt)?  $default,) {final _that = this;
switch (_that) {
case _SongModel() when $default != null:
return $default(_that.id,_that.title,_that.artist,_that.durationMs,_that.source,_that.sourceId,_that.album,_that.artworkUrl,_that.streamUrl,_that.localPath,_that.fileSizeBytes,_that.downloadedAt,_that.downloadProgress,_that.likedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SongModel extends SongModel {
  const _SongModel({required this.id, required this.title, required this.artist, @JsonKey(name: 'duration_ms') required this.durationMs, required this.source, @JsonKey(name: 'source_id') required this.sourceId, this.album, @JsonKey(name: 'artwork_url') this.artworkUrl, @JsonKey(name: 'stream_url') this.streamUrl, @JsonKey(name: 'local_path') this.localPath, @JsonKey(name: 'file_size_bytes') this.fileSizeBytes, @JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter() this.downloadedAt, @JsonKey(includeFromJson: false, includeToJson: false) this.downloadProgress, @JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter() this.likedAt}): super._();
  factory _SongModel.fromJson(Map<String, dynamic> json) => _$SongModelFromJson(json);

@override final  String id;
@override final  String title;
@override final  String artist;
@override@JsonKey(name: 'duration_ms') final  int durationMs;
@override final  SongSource source;
@override@JsonKey(name: 'source_id') final  String sourceId;
@override final  String? album;
@override@JsonKey(name: 'artwork_url') final  String? artworkUrl;
/// Última URL de streaming conocida. Puede estar caducada: tratarla como
/// caché, nunca como fuente de verdad.
@override@JsonKey(name: 'stream_url') final  String? streamUrl;
/// Ruta absoluta del archivo descargado. `null` = no descargada.
@override@JsonKey(name: 'local_path') final  String? localPath;
/// Tamaño en disco del archivo descargado (para la vista "Descargas").
@override@JsonKey(name: 'file_size_bytes') final  int? fileSizeBytes;
@override@JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter() final  DateTime? downloadedAt;
/// Estado transitorio de UI (0.0 – 1.0). NO se persiste en la BD; la
/// fuente de verdad del progreso es el stream del gestor de descargas.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  double? downloadProgress;
/// Cuándo se marcó "me gusta". `null` = no está en Favoritos. Se lee de
/// la BD pero NO se escribe en [toJson]: así `SongDao.upsert` nunca borra
/// un like; solo lo escribe `SongDao.setLiked`.
@override@JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter() final  DateTime? likedAt;

/// Create a copy of SongModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SongModelCopyWith<_SongModel> get copyWith => __$SongModelCopyWithImpl<_SongModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SongModelToJson(this, );
}





}

/// @nodoc
abstract mixin class _$SongModelCopyWith<$Res> implements $SongModelCopyWith<$Res> {
  factory _$SongModelCopyWith(_SongModel value, $Res Function(_SongModel) _then) = __$SongModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String artist,@JsonKey(name: 'duration_ms') int durationMs, SongSource source,@JsonKey(name: 'source_id') String sourceId, String? album,@JsonKey(name: 'artwork_url') String? artworkUrl,@JsonKey(name: 'stream_url') String? streamUrl,@JsonKey(name: 'local_path') String? localPath,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes,@JsonKey(name: 'downloaded_at')@NullableMillisDateTimeConverter() DateTime? downloadedAt,@JsonKey(includeFromJson: false, includeToJson: false) double? downloadProgress,@JsonKey(name: 'liked_at', includeToJson: false)@NullableMillisDateTimeConverter() DateTime? likedAt
});




}
/// @nodoc
class __$SongModelCopyWithImpl<$Res>
    implements _$SongModelCopyWith<$Res> {
  __$SongModelCopyWithImpl(this._self, this._then);

  final _SongModel _self;
  final $Res Function(_SongModel) _then;

/// Create a copy of SongModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? artist = null,Object? durationMs = null,Object? source = null,Object? sourceId = null,Object? album = freezed,Object? artworkUrl = freezed,Object? streamUrl = freezed,Object? localPath = freezed,Object? fileSizeBytes = freezed,Object? downloadedAt = freezed,Object? downloadProgress = freezed,Object? likedAt = freezed,}) {
  return _then(_SongModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SongSource,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,streamUrl: freezed == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,downloadProgress: freezed == downloadProgress ? _self.downloadProgress : downloadProgress // ignore: cast_nullable_to_non_nullable
as double?,likedAt: freezed == likedAt ? _self.likedAt : likedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
