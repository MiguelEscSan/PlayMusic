import '../../../core/domain/entities/song.dart';
import '../domain/remote_playlist.dart';

/// Un resultado de búsqueda candidato a ser la pista buscada, con los datos
/// en bruto que hacen falta para puntuarlo (título y canal sin limpiar).
final class MatchCandidate {
  const MatchCandidate({
    required this.title,
    required this.channel,
    required this.duration,
    required this.isLive,
    required this.song,
  });

  final String title;
  final String channel;
  final Duration? duration;
  final bool isLive;

  /// La canción que se guardaría si este candidato gana.
  final Song song;
}

/// Puntuación mínima para aceptar un candidato (sobre 1).
const minMatchScore = 0.6;

/// Diferencia de duración hasta la que un candidato se considera la misma
/// grabación; hasta [_maxDurationDiff] se acepta con penalización.
const _goodDurationDiff = 10;
const _maxDurationDiff = 30;

/// Palabras que marcan un directo.
const _liveWords = [
  'live',
  'en vivo',
  'en directo',
  'directo',
  'concierto',
  'concert',
];

/// Versiones que no son la grabación original.
const _variantWords = [
  'cover',
  'karaoke',
  'instrumental',
  'remix',
  '8d',
  'slowed',
  'sped up',
  'nightcore',
  'reverb',
  'tutorial',
  'reaction',
];

/// Texto de búsqueda: "artista principal título".
String matchQuery(RemoteTrack track) =>
    [if (track.artists.isNotEmpty) track.artists.first, track.title].join(' ');

/// Puntuación (0..1) de [c] como versión de [track], o null si no es
/// aceptable: directo o versión distinta (salvo que la pista también lo
/// sea), duración a más de 30 s, título distinto o ningún artista en el
/// título ni en el canal.
double? scoreCandidate(RemoteTrack track, MatchCandidate c) {
  final duration = c.duration;
  if (duration == null) return null;

  final trackText = ' ${_normalize(track.title)} ';
  final candidateTitle = ' ${_normalize(c.title)} ';
  if (c.isLive && !_hasAny(trackText, _liveWords)) return null;
  for (final words in const [_liveWords, _variantWords]) {
    for (final word in words) {
      if (candidateTitle.contains(' $word ') &&
          !trackText.contains(' $word ')) {
        return null;
      }
    }
  }

  final diff = (duration.inMilliseconds - track.durationMs).abs() / 1000;
  if (diff > _maxDurationDiff) return null;
  final durationScore = diff <= _goodDurationDiff
      ? 1 - diff / (2 * _goodDurationDiff)
      : 0.5 *
            (_maxDurationDiff - diff) /
            (_maxDurationDiff - _goodDurationDiff);

  final titleTokens = _tokens(_coreTitle(track.title));
  final titleScore = _coverage(titleTokens, _tokens(c.title));
  if (titleScore < 0.5) return null;

  final candidateAll = _tokens('${c.title} ${c.channel}');
  var artistScore = 0.0;
  for (final artist in track.artists) {
    final s = _coverage(_tokens(artist), candidateAll);
    if (s > artistScore) artistScore = s;
  }
  if (track.artists.isNotEmpty && artistScore == 0) return null;
  if (track.artists.isEmpty) artistScore = 0.5;

  return 0.35 * titleScore +
      0.25 * artistScore +
      0.25 * durationScore +
      0.15 * _channelScore(track, c);
}

/// El candidato con mejor puntuación, o null si ninguno es aceptable.
/// A igualdad gana el primero (el orden de la búsqueda).
MatchCandidate? pickBestMatch(
  RemoteTrack track,
  List<MatchCandidate> candidates,
) {
  MatchCandidate? best;
  var bestScore = minMatchScore;
  for (final c in candidates) {
    final score = scoreCandidate(track, c);
    if (score != null &&
        score >= bestScore &&
        (best == null || score > bestScore)) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}

/// Canales oficiales: los automáticos de YouTube Music ("Artista - Topic"),
/// VEVO o el propio canal del artista.
double _channelScore(RemoteTrack track, MatchCandidate c) {
  final channel = c.channel.trim();
  if (RegExp(r'\s-\sTopic$').hasMatch(channel)) return 1;
  final normalized = _normalize(channel);
  if (normalized.endsWith('vevo')) return 0.9;
  if (track.artists.isNotEmpty) {
    final artist = _normalize(track.artists.first);
    if (artist.isNotEmpty &&
        normalized.replaceAll(' ', '') == artist.replaceAll(' ', '')) {
      return 0.8;
    }
  }
  final title = ' ${_normalize(c.title)} ';
  if (title.contains(' official ') || title.contains(' oficial ')) return 0.5;
  return 0;
}

/// Título sin lo que Spotify añade: "(feat. X)", "[...]" o " - Remastered".
String _coreTitle(String title) {
  var core = title.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
  final dash = core.indexOf(' - ');
  if (dash > 0) core = core.substring(0, dash);
  return core.trim().isEmpty ? title : core;
}

bool _hasAny(String paddedText, List<String> words) =>
    words.any((w) => paddedText.contains(' $w '));

/// Fracción de [wanted] que aparece en [found].
double _coverage(List<String> wanted, List<String> found) {
  if (wanted.isEmpty) return 0;
  final set = found.toSet();
  return wanted.where(set.contains).length / wanted.length;
}

List<String> _tokens(String text) =>
    _normalize(text).split(' ').where((t) => t.isNotEmpty).toList();

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// Minúsculas, sin tildes y solo letras/números separados por un espacio.
String _normalize(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
