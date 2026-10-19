import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:koda/core/data/models/millis_date_time_converter.dart';
import 'package:koda/core/data/models/song_model.dart';
import 'package:koda/core/domain/entities/playlist.dart' as domain;

part 'playlist_model.freezed.dart';
part 'playlist_model.g.dart';

/// DTO de la capa de datos: playlist del usuario. Puede mezclar canciones en
/// streaming y descargadas: la playlist solo guarda el orden, cada
/// [SongModel] decide cómo se reproduce. Se convierte a la entidad de
/// dominio con [toEntity] / [PlaylistModel.fromEntity].
///
/// En sqflite se persiste en dos tablas:
///   playlists       (id, name, description, cover_url, created_at, updated_at)
///   playlist_songs  (playlist_id, song_id, position)  PK(playlist_id, position)
/// `position` es lo que permite reordenar sin tocar la tabla `songs`.
///
/// `toJson` solo produce la fila de `playlists`: [songs] vive en otra tabla y
/// se inyecta aparte (ver [PlaylistModel.fromRow]).
@freezed
abstract class PlaylistModel with _$PlaylistModel {
  const PlaylistModel._();

  const factory PlaylistModel({
    required String id,
    required String name,
    @JsonKey(name: 'created_at')
    @MillisDateTimeConverter()
    required DateTime createdAt,
    @JsonKey(name: 'updated_at')
    @MillisDateTimeConverter()
    required DateTime updatedAt,
    String? description,

    /// Portada personalizada; si es null la UI usa la carátula de la 1ª
    /// canción.
    @JsonKey(name: 'cover_url') String? coverUrl,

    /// Canciones en el orden de la playlist. No es una columna de
    /// `playlists`.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<SongModel>[])
    List<SongModel> songs,
  }) = _PlaylistModel;

  /// Construye el DTO desde la entidad de dominio, manteniendo el orden de
  /// las canciones.
  factory PlaylistModel.fromEntity(domain.Playlist entity) => PlaylistModel(
    id: entity.id,
    name: entity.name,
    description: entity.description,
    coverUrl: entity.coverUrl,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
    songs: [for (final song in entity.songs) SongModel.fromEntity(song)],
  );

  /// Lee una fila de la tabla `playlists` (sin canciones).
  factory PlaylistModel.fromJson(Map<String, Object?> json) =>
      _$PlaylistModelFromJson(json);

  /// Fila de `playlists` más sus canciones, ya ordenadas.
  factory PlaylistModel.fromRow(
    Map<String, Object?> row, {
    List<SongModel> songs = const [],
  }) => PlaylistModel.fromJson(row).copyWith(songs: songs);

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

  /// Devuelve una copia con la canción movida (para ReorderableListView).
  PlaylistModel reorder(int oldIndex, int newIndex) {
    final updated = [...songs];
    final song = updated.removeAt(oldIndex);
    updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, song);
    return copyWith(songs: updated, updatedAt: DateTime.now());
  }

  /// Convierte el DTO en la entidad de dominio (canciones en el mismo orden).
  domain.Playlist toEntity() => domain.Playlist(
    id: id,
    name: name,
    description: description,
    coverUrl: coverUrl,
    createdAt: createdAt,
    updatedAt: updatedAt,
    songs: [for (final song in songs) song.toEntity()],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModel &&
          other.id == id &&
          other.updatedAt == updatedAt &&
          listEquals(other.songs, songs);

  @override
  int get hashCode => Object.hash(id, updatedAt, Object.hashAll(songs));
}
