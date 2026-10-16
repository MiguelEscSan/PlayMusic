import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/export/data/method_channel_song_exporter.dart';
import 'package:sponify/features/export/domain/i_song_exporter.dart';

Song _song({String? localPath, String title = 'Título', String artist = 'A'}) =>
    Song(
      id: 'id1',
      title: title,
      artist: artist,
      durationMs: 1000,
      source: SongSource.youtube,
      sourceId: 'yt1',
      localPath: localPath,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sponify/export');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final exporter = MethodChannelSongExporter();

  late List<MethodCall> calls;

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('envía ruta, nombre visible y tipo MIME', () async {
    mock((_) async => 'Music/Koda/Bad Bunny - Tití.m4a');

    final location = await exporter.export(
      _song(
        localPath: '/data/music/id1.m4a',
        title: 'Tití',
        artist: 'Bad Bunny',
      ),
    );

    expect(location, const Ok('Music/Koda/Bad Bunny - Tití.m4a'));
    expect(calls.single.method, 'exportAudio');
    expect(calls.single.arguments, {
      'path': '/data/music/id1.m4a',
      'displayName': 'Bad Bunny - Tití.m4a',
      'mimeType': 'audio/mp4',
    });
  });

  test('tipo MIME según la extensión', () {
    expect(exportMimeType('/a/b.m4a'), 'audio/mp4');
    expect(exportMimeType('/a/b.WEBM'), 'audio/webm');
    expect(exportMimeType('/a/b.mp3'), 'audio/mpeg');
    expect(exportMimeType('/a/b'), 'application/octet-stream');
  });

  test('el nombre visible quita caracteres no válidos', () {
    final name = exportDisplayName(
      _song(title: 'Hola: ¿qué? / "tal"*', artist: 'AC/DC'),
      '/x/y.webm',
    );
    expect(name, 'AC_DC - Hola_ ¿qué_ _ _tal__.webm');
    expect(
      exportDisplayName(_song(title: '  ', artist: ' '), '/x/y.mp3'),
      'Canción.mp3',
    );
  });

  test('una canción sin descargar no llama a la plataforma', () async {
    mock((_) async => 'x');
    expect(
      (await exporter.export(_song())).failureOrNull,
      isA<SongExportFailure>().having(
        (e) => e.error,
        'error',
        SongExportError.notDownloaded,
      ),
    );
    expect(calls, isEmpty);
  });

  test('traduce los códigos de error de la plataforma', () async {
    const cases = {
      'not_found': SongExportError.fileNotFound,
      'permission_denied': SongExportError.permissionDenied,
      'io_error': SongExportError.failed,
    };
    for (final entry in cases.entries) {
      mock((_) async => throw PlatformException(code: entry.key));
      expect(
        (await exporter.export(_song(localPath: '/m/a.m4a'))).failureOrNull,
        isA<SongExportFailure>().having((e) => e.error, 'error', entry.value),
      );
    }
  });

  test('sin implementación nativa avisa de que no es compatible', () async {
    // Sin handler el canal lanza MissingPluginException.
    expect(
      (await exporter.export(_song(localPath: '/m/a.m4a'))).failureOrNull,
      isA<SongExportFailure>().having(
        (e) => e.error,
        'error',
        SongExportError.unsupported,
      ),
    );
  });

  test('todos los errores tienen mensaje en español', () {
    for (final error in SongExportError.values) {
      expect(SongExportFailure(error).message, isNotEmpty);
    }
  });
}
