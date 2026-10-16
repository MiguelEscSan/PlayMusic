import 'package:flutter/services.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/error/result.dart';
import '../domain/i_song_exporter.dart';

/// Implementación Android: el código nativo vive en `MainActivity.kt`.
/// Los errores de la plataforma llegan como `Err(SongExportFailure)`.
class MethodChannelSongExporter implements ISongExporter {
  MethodChannelSongExporter([
    this._channel = const MethodChannel('sponify/export'),
  ]);

  final MethodChannel _channel;

  @override
  Future<Result<String>> export(Song song) async {
    final path = song.localPath;
    if (path == null) {
      return Err(SongExportFailure(SongExportError.notDownloaded));
    }
    try {
      final location = await _channel.invokeMethod<String>('exportAudio', {
        'path': path,
        'displayName': exportDisplayName(song, path),
        'mimeType': exportMimeType(path),
      });
      return Ok(location ?? 'Música/Koda');
    } on MissingPluginException catch (e, st) {
      return Err(
        SongExportFailure(
          SongExportError.unsupported,
          details: e.message,
          cause: e,
          stackTrace: st,
        ),
      );
    } on PlatformException catch (e, st) {
      return Err(
        SongExportFailure(
          switch (e.code) {
            'not_found' => SongExportError.fileNotFound,
            'permission_denied' => SongExportError.permissionDenied,
            _ => SongExportError.failed,
          },
          details: e.message,
          cause: e,
          stackTrace: st,
        ),
      );
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
