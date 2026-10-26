/// Grupos de letras acentuadas e sua letra base.
const Map<String, String> _accentGroups = {
  'a': 'àáâãäåāăą',
  'c': 'çćĉč',
  'd': 'ďđ',
  'e': 'èéêëēėęě',
  'g': 'ĝğģ',
  'i': 'ìíîïīįı',
  'l': 'ĺļľł',
  'n': 'ñńņň',
  'o': 'òóôõöøōő',
  'r': 'ŕř',
  's': 'śŝşš',
  't': 'ţť',
  'u': 'ùúûüūůűų',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final Map<int, String> _accentMap = {
  for (final e in _accentGroups.entries)
    for (final r in e.value.runes) r: e.key,
};

/// Remove acentos e converte para minúsculas, para buscas tolerantes
/// ("Sao Paulo" encontra "São Paulo").
String normalizeText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buffer.write(_accentMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}
