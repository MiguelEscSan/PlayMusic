import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponify/core/audio/audio_player_service.dart';
import 'package:sponify/core/audio/audio_providers.dart';
import 'package:sponify/core/di/repository_providers.dart';
import 'package:sponify/core/domain/entities/playlist.dart';
import 'package:sponify/core/domain/entities/song.dart';
import 'package:sponify/core/error/failure.dart';
import 'package:sponify/core/error/result.dart';
import 'package:sponify/features/downloads/presentation/downloads_providers.dart';
import 'package:sponify/features/favorites/presentation/favorites_providers.dart';
import 'package:sponify/features/playlists/presentation/playlist_detail_screen.dart';

import '../domain/fakes/fake_playlist_repository.dart';
import '../helpers/fixed_notifiers.dart';

Song _song(int i) => Song(
  id: 'id$i',
  title: 'Canción $i',
  artist: 'Artista',
  durationMs: 1000,
  source: SongSource.youtube,
  sourceId: 'yt$i',
);

final _playlist = Playlist(
  id: 'p1',
  name: 'Mi lista',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  songs: [_song(0), _song(1)],
);

/// Devuelve [loads] en orden al cargar (el último se repite) y
/// [removeResult] al quitar.
class _Repository extends FakePlaylistRepository {
  _Repository(this.loads);

  final List<Result<Playlist>> loads;
  Result<Unit> removeResult = const Ok(unit);

  @override
  Future<Result<Playlist>> findById(String id) async =>
      loads.length > 1 ? loads.removeAt(0) : loads.single;

  @override
  Future<Result<List<Playlist>>> getAll() async => Ok([_playlist]);

  @override
  Future<Result<Unit>> removeSongAt(String playlistId, int index) async =>
      removeResult;
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, _Repository repository) async {
    // La cabecera (portada de 250) deja las filas fuera de los 600 px por
    // defecto.
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWithValue(repository),
          playerSnapshotProvider.overrideWith(
            (ref) => const Stream<PlayerSnapshot>.empty(),
          ),
          likedSongsProvider.overrideWith(FixedLikedSongs.new),
          downloadedSongsProvider.overrideWith(FixedDownloads.new),
          downloadTasksProvider.overrideWith((ref) => Stream.value(const {})),
        ],
        child: const MaterialApp(home: PlaylistDetailScreen(id: 'p1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('F1: si la BD no quita la canción, vuelve y se avisa', (
    tester,
  ) async {
    final repository = _Repository([Ok(_playlist)])
      ..removeResult = const Err(DatabaseFailure('disco lleno'));
    await pumpScreen(tester, repository);

    await tester.drag(find.text('Canción 1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Canción 1'), findsOneWidget);
    expect(find.text('No se pudo quitar la canción'), findsOneWidget);
  });

  testWidgets('quitar con Ok deja la fila fuera y ofrece deshacer', (
    tester,
  ) async {
    await pumpScreen(tester, _Repository([Ok(_playlist)]));

    await tester.drag(find.text('Canción 1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Canción 1'), findsNothing);
    expect(find.text('Quitada de "Mi lista"'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('un fallo al cargar muestra el error y reintentar recarga', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _Repository([const Err(DatabaseFailure('disco lleno')), Ok(_playlist)]),
    );

    expect(find.text('No se pudo abrir la playlist'), findsOneWidget);
    expect(find.text('disco lleno'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Mi lista'), findsOneWidget);
    expect(find.text('Canción 0'), findsOneWidget);
  });

  testWidgets('una playlist borrada muestra que ya no existe', (tester) async {
    await pumpScreen(
      tester,
      _Repository([const Err(NotFoundFailure('p1 not found'))]),
    );
    expect(find.text('Esta playlist ya no existe'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
}
