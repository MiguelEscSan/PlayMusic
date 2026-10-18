/// Ids de Spotify: 22 caracteres en base 62.
final _spotifyId = RegExp(r'^[A-Za-z0-9]{22}$');

final _spotifyUri = RegExp(r'^spotify:playlist:([A-Za-z0-9]{22})$');

const _spotifyHosts = {'open.spotify.com', 'play.spotify.com'};

/// Id de la playlist de Spotify de [text], o null si no lo es. Acepta:
/// - el enlace web, con o sin parámetros (`?si=…&utm_source=…&pi=…`), con
///   prefijo de idioma (`/intl-es/`) o de embed (`/embed/`);
/// - la URI `spotify:playlist:<id>`;
/// - el id solo (22 caracteres).
String? parseSpotifyPlaylistId(String text) {
  final input = text.trim();
  if (_spotifyId.hasMatch(input)) return input;
  if (_spotifyUri.firstMatch(input) case final m?) return m.group(1);

  final uri = Uri.tryParse(input.contains('://') ? input : 'https://$input');
  if (uri == null || !_spotifyHosts.contains(uri.host.toLowerCase())) {
    return null;
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final i = segments.indexOf('playlist');
  if (i < 0 || i + 1 >= segments.length) return null;
  final id = segments[i + 1];
  return _spotifyId.hasMatch(id) ? id : null;
}

/// Si [text] parece de Spotify (aunque no sea una playlist válida), para
/// elegir el importador y su mensaje de error.
bool isSpotifyLink(String text) {
  final input = text.trim().toLowerCase();
  return parseSpotifyPlaylistId(text) != null ||
      input.startsWith('spotify:') ||
      input.contains('spotify.com') ||
      input.contains('spotify.link');
}
