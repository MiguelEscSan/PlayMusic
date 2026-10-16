import 'package:sponify/core/domain/entities/song.dart';

/// Clave estable de una canción (`source:sourceId`). No depende del id de
/// la BD, así que identifica también un resultado de búsqueda que aún no
/// está guardado (progreso de descarga, corazón de "me gusta"...).
String songKey(Song song) => '${song.source.name}:${song.sourceId}';
