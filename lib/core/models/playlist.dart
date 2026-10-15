import 'package:flutter/foundation.dart';

import 'song.dart';

/// Playlist del usuario. Puede mezclar canciones en streaming y descargadas:
/// la playlist solo guarda el orden, cada [Song] decide cómo se reproduce.
///
/// En sqflite se persiste en dos tablas:
///   playlists       (id, name, description, cover_url, created_at, updated_at)
///   playlist_songs  (playlist_id, song_id, position)  PK(playlist_id, position)
/// `position` es lo que permite reordenar sin tocar la tabla `songs`.
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverUrl,
    this.songs = const [],
  });

  final String id;
  final String name;
  final String? description;

  /// Portada personalizada; si es null la UI usa la carátula de la 1ª canción.
  final String? coverUrl;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Canciones en el orden de la playlist.
  final List<Song> songs;

  int get length => songs.length;
  bool get isEmpty => songs.isEmpty;

  Duration get totalDuration =>
      songs.fold(Duration.zero, (total, song) => total + song.duration);

  int get downloadedCount => songs.where((s) => s.isDownloaded).length;

  /// true si toda la playlist se puede escuchar sin conexión.
  bool get isFullyDownloaded => songs.isNotEmpty && downloadedCount == length;

  String? get effectiveCoverUrl =>
      coverUrl ?? (songs.isEmpty ? null : songs.first.artworkUrl);

  /// Imágenes de la portada: la personalizada; si no, un mosaico 2×2 con
  /// las 4 primeras carátulas distintas; con menos de 4, solo la primera.
  /// Vacía si no hay ninguna (se pinta la portada generada).
  List<String> get coverUrls {
    if (coverUrl != null) return [coverUrl!];
    final distinct = <String>[];
    for (final song in songs) {
      final url = song.artworkUrl;
      if (url != null && !distinct.contains(url)) distinct.add(url);
      if (distinct.length == 4) return distinct;
    }
    return distinct.take(1).toList();
  }

  Playlist copyWith({
    String? name,
    String? description,
    String? coverUrl,
    DateTime? updatedAt,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songs: songs ?? this.songs,
    );
  }

  /// Devuelve una copia con la canción movida (para ReorderableListView).
  Playlist reorder(int oldIndex, int newIndex) {
    final updated = [...songs];
    final song = updated.removeAt(oldIndex);
    updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, song);
    return copyWith(songs: updated, updatedAt: DateTime.now());
  }

  /// Fila de la tabla `playlists` (las canciones van en `playlist_songs`).
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'cover_url': coverUrl,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Playlist.fromMap(
    Map<String, Object?> map, {
    List<Song> songs = const [],
  }) => Playlist(
    id: map['id']! as String,
    name: map['name']! as String,
    description: map['description'] as String?,
    coverUrl: map['cover_url'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    songs: songs,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          other.id == id &&
          other.updatedAt == updatedAt &&
          listEquals(other.songs, songs);

  @override
  int get hashCode => Object.hash(id, updatedAt, Object.hashAll(songs));
}
