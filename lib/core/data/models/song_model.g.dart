// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SongModel _$SongModelFromJson(Map<String, dynamic> json) => _SongModel(
  id: json['id'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  durationMs: (json['duration_ms'] as num).toInt(),
  source: $enumDecode(_$SongSourceEnumMap, json['source']),
  sourceId: json['source_id'] as String,
  album: json['album'] as String?,
  artworkUrl: json['artwork_url'] as String?,
  streamUrl: json['stream_url'] as String?,
  localPath: json['local_path'] as String?,
  fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
  downloadedAt: const NullableMillisDateTimeConverter().fromJson(
    (json['downloaded_at'] as num?)?.toInt(),
  ),
  likedAt: const NullableMillisDateTimeConverter().fromJson(
    (json['liked_at'] as num?)?.toInt(),
  ),
);

Map<String, dynamic> _$SongModelToJson(_SongModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'duration_ms': instance.durationMs,
      'source': _$SongSourceEnumMap[instance.source]!,
      'source_id': instance.sourceId,
      'album': instance.album,
      'artwork_url': instance.artworkUrl,
      'stream_url': instance.streamUrl,
      'local_path': instance.localPath,
      'file_size_bytes': instance.fileSizeBytes,
      'downloaded_at': const NullableMillisDateTimeConverter().toJson(
        instance.downloadedAt,
      ),
    };

const _$SongSourceEnumMap = {
  SongSource.youtube: 'youtube',
  SongSource.jamendo: 'jamendo',
  SongSource.local: 'local',
};
