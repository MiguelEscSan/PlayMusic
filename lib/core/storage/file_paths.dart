import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Dónde viven los archivos de audio descargados.
///
/// Se usa el directorio de documentos de la app (privado, no lo borra el
/// sistema al liberar caché y no aparece en la galería del usuario).
class FilePaths {
  FilePaths(this._musicDir);

  final Directory _musicDir;

  static Future<FilePaths> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'music'));
    await dir.create(recursive: true);
    return FilePaths(dir);
  }

  Directory get musicDir => _musicDir;

  /// Portadas de playlist elegidas por el usuario (se crea al guardar la
  /// primera).
  Directory get coversDir =>
      Directory(p.join(p.dirname(_musicDir.path), 'covers'));

  /// Ruta final del archivo de una canción, p. ej. `.../music/<id>.m4a`.
  String songFile(String songId, String extension) =>
      p.join(_musicDir.path, '$songId.$extension');

  /// Archivo temporal mientras se descarga. Solo se renombra al final, así
  /// nunca se reproduce un archivo a medias.
  String partialFile(String songId) => p.join(_musicDir.path, '$songId.part');
}
