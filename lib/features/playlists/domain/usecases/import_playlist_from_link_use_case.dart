import 'package:koda/core/domain/guard.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';
import 'package:koda/features/playlists/domain/i_playlist_importer.dart';
import 'package:koda/features/playlists/domain/spotify_playlist_link.dart';

/// Servicio del que viene un enlace de playlist.
enum PlaylistLinkSource { youtube, spotify }

/// Importa una playlist a partir de un enlace de YouTube o de Spotify,
/// eligiendo el importador por el enlace: lo que parece de Spotify va a
/// [spotify]; todo lo demás, a [youtube] (como antes). Los fallos llegan
/// tipados (ver [IPlaylistImporter]); una excepción inesperada llega como
/// `Err(NetworkFailure)`.
final class ImportPlaylistFromLinkUseCase {
  const ImportPlaylistFromLinkUseCase({
    required this.youtube,
    required this.spotify,
  });

  final IPlaylistImporter youtube;
  final IPlaylistImporter spotify;

  PlaylistLinkSource sourceOf(String link) => isSpotifyLink(link)
      ? PlaylistLinkSource.spotify
      : PlaylistLinkSource.youtube;

  Future<Result<ImportResult>> call(String link, {ImportProgress? onProgress}) {
    final importer = switch (sourceOf(link)) {
      PlaylistLinkSource.spotify => spotify,
      PlaylistLinkSource.youtube => youtube,
    };
    return guardResult(
      () => importer.importFromUrl(link, onProgress: onProgress),
      onError: (e, st) => NetworkFailure(
        'No se pudo importar la playlist',
        cause: e,
        stackTrace: st,
      ),
    );
  }
}
