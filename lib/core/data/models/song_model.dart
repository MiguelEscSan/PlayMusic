import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:koda/core/data/models/millis_date_time_converter.dart';
import 'package:koda/core/domain/entities/song.dart' show SongSource;
import 'package:koda/core/domain/entities/song.dart' as domain;

export 'package:koda/core/domain/entities/song.dart' show SongSource;

part 'song_model.freezed.dart';
part 'song_model.g.dart';

/// DTO de la capa de datos: una pista reproducible en streaming u offline,
/// tal y como se guarda en la tabla `songs`. Se convierte a la entidad de
/// dominio con [toEntity] / [SongModel.fromEntity].
///
/// Regla de oro del reproductor híbrido:
///   - si [localPath] != null y el archivo existe  -> se reproduce local
///   - en otro caso                                -> streaming
/// La comprobación de que el archivo existe la hace el resolver del servicio
/// de audio (ver `PlaybackSourceResolver`), no el modelo.
///
/// `fromJson` / `toJson` hablan el esquema de la tabla (claves en
/// snake_case, fechas en milisegundos).
@freezed
abstract class SongModel with _$SongModel {
  const SongModel._();

  const factory SongModel({
    required String id,
    required String title,
    required String artist,
    @JsonKey(name: 'duration_ms') required int durationMs,
    required SongSource source,
    @JsonKey(name: 'source_id') required String sourceId,
    String? album,
    @JsonKey(name: 'artwork_url') String? artworkUrl,

    /// Última URL de streaming conocida. Puede estar caducada: tratarla como
    /// caché, nunca como fuente de verdad.
    @JsonKey(name: 'stream_url') String? streamUrl,

    /// Ruta absoluta del archivo descargado. `null` = no descargada.
    @JsonKey(name: 'local_path') String? localPath,

    /// Tamaño en disco del archivo descargado (para la vista "Descargas").
    @JsonKey(name: 'file_size_bytes') int? fileSizeBytes,
    @JsonKey(name: 'downloaded_at')
    @NullableMillisDateTimeConverter()
    DateTime? downloadedAt,

    /// Estado transitorio de UI (0.0 – 1.0). NO se persiste en la BD; la
    /// fuente de verdad del progreso es el stream del gestor de descargas.
    @JsonKey(includeFromJson: false, includeToJson: false)
    double? downloadProgress,

    /// Cuándo se marcó "me gusta". `null` = no está en Favoritos. Se lee de
    /// la BD pero NO se escribe en [toJson]: así `SongDao.upsert` nunca borra
    /// un like; solo lo escribe `SongDao.setLiked`.
    @JsonKey(name: 'liked_at', includeToJson: false)
    @NullableMillisDateTimeConverter()
    DateTime? likedAt,
  }) = _SongModel;

  /// Construye el DTO desde la entidad de dominio. [downloadProgress] queda
  /// a `null`: el dominio no conoce el estado transitorio de UI.
  factory SongModel.fromEntity(domain.Song entity) => SongModel(
    id: entity.id,
    title: entity.title,
    artist: entity.artist,
    album: entity.album,
    durationMs: entity.durationMs,
    artworkUrl: entity.artworkUrl,
    source: entity.source,
    sourceId: entity.sourceId,
    streamUrl: entity.streamUrl,
    localPath: entity.localPath,
    fileSizeBytes: entity.fileSizeBytes,
    downloadedAt: entity.downloadedAt,
    likedAt: entity.likedAt,
  );

  /// Lee una fila de la tabla `songs`.
  factory SongModel.fromJson(Map<String, Object?> json) =>
      _$SongModelFromJson(json);

  bool get isLiked => likedAt != null;

  /// Derivado de [localPath] para que nunca pueda quedar desincronizado.
  bool get isDownloaded => localPath != null;

  bool get isDownloading =>
      downloadProgress != null && downloadProgress! < 1.0 && !isDownloaded;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Convierte el DTO en la entidad de dominio (sin [downloadProgress]).
  domain.Song toEntity() => domain.Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkUrl: artworkUrl,
    source: source,
    sourceId: sourceId,
    streamUrl: streamUrl,
    localPath: localPath,
    fileSizeBytes: fileSizeBytes,
    downloadedAt: downloadedAt,
    likedAt: likedAt,
  );

  /// Dos canciones son la misma si coinciden en origen; evita duplicados
  /// cuando el usuario guarda dos veces el mismo resultado de búsqueda.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel &&
          other.source == source &&
          other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(source, sourceId);

  @override
  String toString() => 'Song($title — $artist, downloaded: $isDownloaded)';
}
