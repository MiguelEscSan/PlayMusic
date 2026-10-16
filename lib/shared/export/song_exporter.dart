import 'package:flutter/services.dart';

import '../../core/domain/entities/song.dart';

/// Copia una canción descargada a la carpeta pública de Música del móvil,
/// para que otras apps (reproductores, gestores de archivos) la vean.
abstract interface class SongExporter {
  /// Devuelve una descripción legible de dónde ha quedado el archivo.
  /// Lanza [SongExportException] si no se puede exportar.
  Future<String> export(Song song);
}

enum SongExportError {
  notDownloaded,
  fileNotFound,
  permissionDenied,
  unsupported,
  failed,
}

class SongExportException implements Exception {
  const SongExportException(this.error, [this.details]);

  final SongExportError error;

  /// Mensaje técnico de la plataforma (solo para depurar).
  final String? details;

  /// Texto para mostrar al usuario.
  String get message => switch (error) {
    SongExportError.notDownloaded => 'La canción no está descargada',
    SongExportError.fileNotFound => 'No se encuentra el archivo descargado',
    SongExportError.permissionDenied =>
      'Sin permiso para guardar en la carpeta Música',
    SongExportError.unsupported => 'Exportar no está disponible aquí',
    SongExportError.failed => 'No se pudo exportar la canción',
  };

  @override
  String toString() => 'SongExportException($error, $details)';
}

/// Implementación Android: el código nativo vive en `MainActivity.kt`.
class MethodChannelSongExporter implements SongExporter {
  MethodChannelSongExporter([
    this._channel = const MethodChannel('sponify/export'),
  ]);

  final MethodChannel _channel;

  @override
  Future<String> export(Song song) async {
    final path = song.localPath;
    if (path == null) {
      throw const SongExportException(SongExportError.notDownloaded);
    }
    try {
      final location = await _channel.invokeMethod<String>('exportAudio', {
        'path': path,
        'displayName': exportDisplayName(song, path),
        'mimeType': exportMimeType(path),
      });
      return location ?? 'Música/Koda';
    } on MissingPluginException catch (e) {
      throw SongExportException(SongExportError.unsupported, e.message);
    } on PlatformException catch (e) {
      throw SongExportException(switch (e.code) {
        'not_found' => SongExportError.fileNotFound,
        'permission_denied' => SongExportError.permissionDenied,
        _ => SongExportError.failed,
      }, e.message);
    }
  }
}

/// Caracteres que no admiten los sistemas de archivos habituales.
final _invalidChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

/// "Artista - Título.ext", sin caracteres problemáticos para un nombre de
/// archivo. La extensión sale del archivo descargado.
String exportDisplayName(Song song, String path) {
  String clean(String s) => s.replaceAll(_invalidChars, '_').trim();
  final artist = clean(song.artist);
  final title = clean(song.title);
  final base = [artist, title].where((s) => s.isNotEmpty).join(' - ');
  return '${base.isEmpty ? 'Canción' : base}${_extension(path)}';
}

String exportMimeType(String path) => switch (_extension(path)) {
  '.m4a' => 'audio/mp4',
  '.webm' => 'audio/webm',
  '.mp3' => 'audio/mpeg',
  _ => 'application/octet-stream',
};

String _extension(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot).toLowerCase();
}
