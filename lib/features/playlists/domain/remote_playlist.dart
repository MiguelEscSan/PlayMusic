/// Una pista de una playlist de otro servicio (p. ej. Spotify), tal como la
/// necesita el dominio: sin ids ni formatos del servicio de origen.
final class RemoteTrack {
  const RemoteTrack({
    required this.title,
    required this.artists,
    required this.durationMs,
  });

  final String title;

  /// Artistas en el orden en que los da el servicio; el primero es el
  /// principal.
  final List<String> artists;

  /// Duración en milisegundos.
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTrack &&
          other.title == title &&
          other.durationMs == durationMs &&
          _sameList(other.artists, artists);

  @override
  int get hashCode => Object.hash(title, durationMs, Object.hashAll(artists));

  @override
  String toString() => 'RemoteTrack(${artists.join(', ')} - $title)';
}

/// Una playlist de otro servicio: su nombre y las pistas que se pudieron
/// leer.
final class RemotePlaylist {
  const RemotePlaylist({
    required this.name,
    required this.tracks,
    this.totalCount,
  });

  final String name;
  final List<RemoteTrack> tracks;

  /// Número real de pistas de la playlist, si el servicio lo dice. Puede ser
  /// mayor que `tracks.length` cuando el servicio solo deja leer una parte;
  /// null si no se sabe.
  final int? totalCount;

  RemotePlaylist copyWith({int? totalCount}) => RemotePlaylist(
    name: name,
    tracks: tracks,
    totalCount: totalCount ?? this.totalCount,
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
