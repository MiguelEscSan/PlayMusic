import 'package:flutter/foundation.dart';
import 'package:sponify/core/domain/entities/song.dart' show SongSource;
import 'package:sponify/core/domain/entities/song.dart' as domain;

export 'package:sponify/core/domain/entities/song.dart' show SongSource;

/// DTO de la capa de datos: una pista reproducible en streaming u offline,
/// tal y como se guarda en la tabla `songs`. Se convierte a la entidad de
/// dominio con [toEntity] / [SongModel.fromEntity].
///
/// Regla de oro del reproductor híbrido:
///   - si [localPath] != null y el archivo existe  -> se reproduce local
///   - en otro caso                                -> streaming
/// La comprobación de que el archivo existe la hace el resolver del servicio
/// de audio (ver `PlaybackSourceResolver`), no el modelo.
@immutable
class SongModel {
  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.source,
    required this.sourceId,
    this.album,
    this.artworkUrl,
    this.streamUrl,
    this.localPath,
    this.fileSizeBytes,
    this.downloadedAt,
    this.downloadProgress,
    this.likedAt,
  });

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

  /// Identificador interno estable (UUID v4 generado al guardar en la BD).
  final String id;

  final String title;
  final String artist;
  final String? album;

  /// Duración en milisegundos.
  final int durationMs;

  final String? artworkUrl;

  /// De dónde viene la pista y su id en ese origen (p. ej. el videoId de
  /// YouTube). Con estos dos campos siempre podemos pedir una URL fresca.
  final SongSource source;
  final String sourceId;

  /// Última URL de streaming conocida. Puede estar caducada: tratarla como
  /// caché, nunca como fuente de verdad.
  final String? streamUrl;

  /// Ruta absoluta del archivo descargado. `null` = no descargada.
  final String? localPath;

  /// Tamaño en disco del archivo descargado (para la vista "Descargas").
  final int? fileSizeBytes;

  final DateTime? downloadedAt;

  /// Estado transitorio de UI (0.0 – 1.0). NO se persiste en la BD; la fuente
  /// de verdad del progreso es el stream del gestor de descargas (Paso 3).
  final double? downloadProgress;

  /// Cuándo se marcó "me gusta". `null` = no está en Favoritos. Se lee de la
  /// BD pero NO va en [toMap]: así `SongDao.upsert` nunca borra un like; solo
  /// lo escribe `SongDao.setLiked`.
  final DateTime? likedAt;

  bool get isLiked => likedAt != null;

  /// Derivado de [localPath] para que nunca pueda quedar desincronizado.
  bool get isDownloaded => localPath != null;

  bool get isDownloading =>
      downloadProgress != null && downloadProgress! < 1.0 && !isDownloaded;

  Duration get duration => Duration(milliseconds: durationMs);

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artworkUrl,
    SongSource? source,
    String? sourceId,
    String? streamUrl,
    String? localPath,
    int? fileSizeBytes,
    DateTime? downloadedAt,
    double? downloadProgress,
    DateTime? likedAt,
    bool clearLocalFile = false,
    bool clearDownloadProgress = false,
    bool clearLiked = false,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      streamUrl: streamUrl ?? this.streamUrl,
      localPath: clearLocalFile ? null : (localPath ?? this.localPath),
      fileSizeBytes: clearLocalFile
          ? null
          : (fileSizeBytes ?? this.fileSizeBytes),
      downloadedAt: clearLocalFile ? null : (downloadedAt ?? this.downloadedAt),
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      likedAt: clearLiked ? null : (likedAt ?? this.likedAt),
    );
  }

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

  /// Serialización para la tabla `songs` de sqflite.
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration_ms': durationMs,
    'artwork_url': artworkUrl,
    'source': source.name,
    'source_id': sourceId,
    'stream_url': streamUrl,
    'local_path': localPath,
    'file_size_bytes': fileSizeBytes,
    'downloaded_at': downloadedAt?.millisecondsSinceEpoch,
  };

  factory SongModel.fromMap(Map<String, Object?> map) => SongModel(
    id: map['id']! as String,
    title: map['title']! as String,
    artist: map['artist']! as String,
    album: map['album'] as String?,
    durationMs: map['duration_ms']! as int,
    artworkUrl: map['artwork_url'] as String?,
    source: SongSource.values.byName(map['source']! as String),
    sourceId: map['source_id']! as String,
    streamUrl: map['stream_url'] as String?,
    localPath: map['local_path'] as String?,
    fileSizeBytes: map['file_size_bytes'] as int?,
    downloadedAt: map['downloaded_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['downloaded_at']! as int),
    likedAt: map['liked_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['liked_at']! as int),
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
