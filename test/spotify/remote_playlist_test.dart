import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/features/playlists/domain/remote_playlist.dart';

void main() {
  test('dos pistas con los mismos datos son iguales', () {
    const a = RemoteTrack(
      title: 'Dardos',
      artists: ['Romeo Santos', 'Prince Royce'],
      durationMs: 243070,
    );
    const b = RemoteTrack(
      title: 'Dardos',
      artists: ['Romeo Santos', 'Prince Royce'],
      durationMs: 243070,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.duration, const Duration(milliseconds: 243070));
  });

  test('copyWith solo cambia el total', () {
    const playlist = RemotePlaylist(name: 'Mix', tracks: []);
    final withTotal = playlist.copyWith(totalCount: 122);
    expect(withTotal.name, 'Mix');
    expect(withTotal.totalCount, 122);
    expect(playlist.totalCount, isNull);
  });
}
