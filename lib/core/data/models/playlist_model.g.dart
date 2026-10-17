// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlaylistModel _$PlaylistModelFromJson(Map<String, dynamic> json) =>
    _PlaylistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: const MillisDateTimeConverter().fromJson(
        (json['created_at'] as num).toInt(),
      ),
      updatedAt: const MillisDateTimeConverter().fromJson(
        (json['updated_at'] as num).toInt(),
      ),
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
    );

Map<String, dynamic> _$PlaylistModelToJson(_PlaylistModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_at': const MillisDateTimeConverter().toJson(instance.createdAt),
      'updated_at': const MillisDateTimeConverter().toJson(instance.updatedAt),
      'description': instance.description,
      'cover_url': instance.coverUrl,
    };
