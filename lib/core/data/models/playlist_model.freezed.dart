// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playlist_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlaylistModel implements DiagnosticableTreeMixin {

 String get id; String get name;@JsonKey(name: 'created_at')@MillisDateTimeConverter() DateTime get createdAt;@JsonKey(name: 'updated_at')@MillisDateTimeConverter() DateTime get updatedAt; String? get description;/// Portada personalizada; si es null la UI usa la carátula de la 1ª
/// canción.
@JsonKey(name: 'cover_url') String? get coverUrl;/// Canciones en el orden de la playlist. No es una columna de
/// `playlists`.
@JsonKey(includeFromJson: false, includeToJson: false) List<SongModel> get songs;
/// Create a copy of PlaylistModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaylistModelCopyWith<PlaylistModel> get copyWith => _$PlaylistModelCopyWithImpl<PlaylistModel>(this as PlaylistModel, _$identity);

  /// Serializes this PlaylistModel to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as PlaylistModel;
  properties
    ..add(DiagnosticsProperty('type', 'PlaylistModel'))
    ..add(DiagnosticsProperty('id', _this.id))..add(DiagnosticsProperty('name', _this.name))..add(DiagnosticsProperty('createdAt', _this.createdAt))..add(DiagnosticsProperty('updatedAt', _this.updatedAt))..add(DiagnosticsProperty('description', _this.description))..add(DiagnosticsProperty('coverUrl', _this.coverUrl))..add(DiagnosticsProperty('songs', _this.songs));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as PlaylistModel;
  return 'PlaylistModel(id: ${_this.id}, name: ${_this.name}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, coverUrl: ${_this.coverUrl}, songs: ${_this.songs})';
}


}

/// @nodoc
abstract mixin class $PlaylistModelCopyWith<$Res>  {
  factory $PlaylistModelCopyWith(PlaylistModel value, $Res Function(PlaylistModel) _then) = _$PlaylistModelCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'created_at')@MillisDateTimeConverter() DateTime createdAt,@JsonKey(name: 'updated_at')@MillisDateTimeConverter() DateTime updatedAt, String? description,@JsonKey(name: 'cover_url') String? coverUrl,@JsonKey(includeFromJson: false, includeToJson: false) List<SongModel> songs
});




}
/// @nodoc
class _$PlaylistModelCopyWithImpl<$Res>
    implements $PlaylistModelCopyWith<$Res> {
  _$PlaylistModelCopyWithImpl(this._self, this._then);

  final PlaylistModel _self;
  final $Res Function(PlaylistModel) _then;

/// Create a copy of PlaylistModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? description = freezed,Object? coverUrl = freezed,Object? songs = null,}) {
  return _then(PlaylistModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,songs: null == songs ? _self.songs : songs // ignore: cast_nullable_to_non_nullable
as List<SongModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaylistModel].
extension PlaylistModelPatterns on PlaylistModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaylistModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaylistModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaylistModel value)  $default,){
final _that = this;
switch (_that) {
case _PlaylistModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaylistModel value)?  $default,){
final _that = this;
switch (_that) {
case _PlaylistModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'created_at')@MillisDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@MillisDateTimeConverter()  DateTime updatedAt,  String? description, @JsonKey(name: 'cover_url')  String? coverUrl, @JsonKey(includeFromJson: false, includeToJson: false)  List<SongModel> songs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaylistModel() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.description,_that.coverUrl,_that.songs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'created_at')@MillisDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@MillisDateTimeConverter()  DateTime updatedAt,  String? description, @JsonKey(name: 'cover_url')  String? coverUrl, @JsonKey(includeFromJson: false, includeToJson: false)  List<SongModel> songs)  $default,) {final _that = this;
switch (_that) {
case _PlaylistModel():
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.description,_that.coverUrl,_that.songs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'created_at')@MillisDateTimeConverter()  DateTime createdAt, @JsonKey(name: 'updated_at')@MillisDateTimeConverter()  DateTime updatedAt,  String? description, @JsonKey(name: 'cover_url')  String? coverUrl, @JsonKey(includeFromJson: false, includeToJson: false)  List<SongModel> songs)?  $default,) {final _that = this;
switch (_that) {
case _PlaylistModel() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.description,_that.coverUrl,_that.songs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlaylistModel extends PlaylistModel with DiagnosticableTreeMixin {
  const _PlaylistModel({required this.id, required this.name, @JsonKey(name: 'created_at')@MillisDateTimeConverter() required this.createdAt, @JsonKey(name: 'updated_at')@MillisDateTimeConverter() required this.updatedAt, this.description, @JsonKey(name: 'cover_url') this.coverUrl, @JsonKey(includeFromJson: false, includeToJson: false)  List<SongModel> songs = const <SongModel>[]}): _songs = songs,super._();
  factory _PlaylistModel.fromJson(Map<String, dynamic> json) => _$PlaylistModelFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'created_at')@MillisDateTimeConverter() final  DateTime createdAt;
@override@JsonKey(name: 'updated_at')@MillisDateTimeConverter() final  DateTime updatedAt;
@override final  String? description;
/// Portada personalizada; si es null la UI usa la carátula de la 1ª
/// canción.
@override@JsonKey(name: 'cover_url') final  String? coverUrl;
/// Canciones en el orden de la playlist. No es una columna de
/// `playlists`.
 final  List<SongModel> _songs;
/// Canciones en el orden de la playlist. No es una columna de
/// `playlists`.
@override@JsonKey(includeFromJson: false, includeToJson: false) List<SongModel> get songs {
  if (_songs is EqualUnmodifiableListView) return _songs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_songs);
}


/// Create a copy of PlaylistModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaylistModelCopyWith<_PlaylistModel> get copyWith => __$PlaylistModelCopyWithImpl<_PlaylistModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaylistModelToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'PlaylistModel'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('updatedAt', updatedAt))..add(DiagnosticsProperty('description', description))..add(DiagnosticsProperty('coverUrl', coverUrl))..add(DiagnosticsProperty('songs', songs));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'PlaylistModel(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, description: $description, coverUrl: $coverUrl, songs: $songs)';
}


}

/// @nodoc
abstract mixin class _$PlaylistModelCopyWith<$Res> implements $PlaylistModelCopyWith<$Res> {
  factory _$PlaylistModelCopyWith(_PlaylistModel value, $Res Function(_PlaylistModel) _then) = __$PlaylistModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'created_at')@MillisDateTimeConverter() DateTime createdAt,@JsonKey(name: 'updated_at')@MillisDateTimeConverter() DateTime updatedAt, String? description,@JsonKey(name: 'cover_url') String? coverUrl,@JsonKey(includeFromJson: false, includeToJson: false) List<SongModel> songs
});




}
/// @nodoc
class __$PlaylistModelCopyWithImpl<$Res>
    implements _$PlaylistModelCopyWith<$Res> {
  __$PlaylistModelCopyWithImpl(this._self, this._then);

  final _PlaylistModel _self;
  final $Res Function(_PlaylistModel) _then;

/// Create a copy of PlaylistModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? description = freezed,Object? coverUrl = freezed,Object? songs = null,}) {
  return _then(_PlaylistModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,songs: null == songs ? _self._songs : songs // ignore: cast_nullable_to_non_nullable
as List<SongModel>,
  ));
}


}

// dart format on
