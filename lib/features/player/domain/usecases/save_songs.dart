import 'package:koda/core/domain/entities/song.dart';
import 'package:koda/core/domain/repositories/i_song_repository.dart';
import 'package:koda/core/error/result.dart';

/// Guarda cada canción antes de reproducirla y devuelve las copias
/// guardadas, en el mismo orden. Se vuelve a guardar aunque tenga id: su
/// descarga puede haber cambiado, y así un resultado de búsqueda ya
/// descargado suena desde el archivo local. Guardar solo refresca
/// metadatos (conserva descarga y "me gusta"). Para en el primer `Err`.
Future<Result<List<Song>>> saveSongs(
  ISongRepository songs,
  List<Song> toSave,
) async {
  final saved = <Song>[];
  for (final song in toSave) {
    switch (await songs.save(song)) {
      case Ok(:final value):
        saved.add(value);
      case Err(:final failure):
        return Err(failure);
    }
  }
  return Ok(saved);
}
