/// Origen del que procede una canción. Permite re-resolver la URL de
/// streaming cuando caduca (las URLs de YouTube expiran a las pocas horas).
enum SongSource { youtube, jamendo, local }

/// Entidad de dominio: una pista reproducible en streaming u offline.
///
/// Pura: sin dependencias de Flutter ni de persistencia. La serialización
/// vive en la capa de datos. No incluye el progreso de descarga, que es
/// estado transitorio de UI.
final class Song {
  const Song({
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
    this.likedAt,
  });

  /// Identificador interno estable.
  final String id;

  final String title;
  final String artist;
  final String? album;

  /// Duración en milisegundos.
  final int durationMs;

  final String? artworkUrl;

  /// De dónde viene la pista y su id en ese origen (p. ej. el videoId de
  /// YouTube). Con estos dos campos siempre se puede pedir una URL fresca.
  final SongSource source;
  final String sourceId;

  /// Última URL de streaming conocida. Puede estar caducada: tratarla como
  /// caché, nunca como fuente de verdad.
  final String? streamUrl;

  /// Ruta absoluta del archivo descargado. `null` = no descargada.
  final String? localPath;

  /// Tamaño en disco del archivo descargado.
  final int? fileSizeBytes;

  final DateTime? downloadedAt;

  /// Cuándo se marcó "me gusta". `null` = no está en Favoritos.
  final DateTime? likedAt;

  bool get isLiked => likedAt != null;

  /// Derivado de [localPath] para que nunca pueda quedar desincronizado.
  bool get isDownloaded => localPath != null;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Copia con los campos indicados. [clearLocalFile] borra la ruta, el
  /// tamaño y la fecha de descarga; [clearLiked] quita el "me gusta".
  Song copyWith({
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
    DateTime? likedAt,
    bool clearLocalFile = false,
    bool clearLiked = false,
  }) {
    return Song(
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
      likedAt: clearLiked ? null : (likedAt ?? this.likedAt),
    );
  }

  /// Dos canciones son la misma si coinciden en origen; evita duplicados
  /// cuando el usuario guarda dos veces el mismo resultado de búsqueda.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && other.source == source && other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(source, sourceId);

  @override
  String toString() => 'Song($title — $artist, downloaded: $isDownloaded)';
}
