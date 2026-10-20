/// Estado de reproducción guardado para retomarlo al volver a abrir la app:
/// ids de la cola, índice de la canción que sonaba y posición dentro de ella.
///
/// Solo guarda ids: las URLs de streaming caducan, así que las canciones se
/// vuelven a leer de la base de datos al restaurar.
class LastPlayback {
  const LastPlayback({
    required this.songIds,
    required this.index,
    this.position = Duration.zero,
  });

  final List<String> songIds;
  final int index;
  final Duration position;
}
