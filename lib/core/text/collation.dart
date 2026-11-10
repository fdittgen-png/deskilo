// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3488 -- names sort the way a French, German, Spanish or Italian reader
// expects: `Émile` beside `Emil`, `Über` beside `Uber`, `Ñ` beside `N`, case
// ignored, the order total so a list does not jitter. Dart's `compareTo` is
// UTF-16 code-unit order and puts every accented initial after `Z`.
//
// The fold covers Latin-1 and Latin Extended-A (92 lower-case
// letters); a character outside it keeps its own code point. The sorts of
// the database (`ORDER BY`) follow its collation and are not touched here.

/// The lower-case letters folded to their plain Latin form.
const Map<String, String> _fold = {
  'i̇': 'i',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ð': 'd',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'þ': 'th',
  'ÿ': 'y',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ć': 'c',
  'ĉ': 'c',
  'ċ': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ĝ': 'g',
  'ğ': 'g',
  'ġ': 'g',
  'ģ': 'g',
  'ĥ': 'h',
  'ĩ': 'i',
  'ī': 'i',
  'ĭ': 'i',
  'į': 'i',
  'ı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺ': 'l',
  'ļ': 'l',
  'ľ': 'l',
  'ł': 'l',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'ŉ': 'n',
  'ŋ': 'n',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r',
  'ŗ': 'r',
  'ř': 'r',
  'ś': 's',
  'ŝ': 's',
  'ş': 's',
  'š': 's',
  'ţ': 't',
  'ť': 't',
  'ũ': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ŵ': 'w',
  'ŷ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};

/// [name] lower-cased with its diacritics (and `ß`, `œ`, `æ`) folded away:
/// what a search compares, so `Zurich` finds `Zürich`.
String foldForSearch(String name) => _folded(name);

String _folded(String name) {
  final lower = name.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_fold[c] ?? c);
  }
  return out.toString();
}

/// Orders two names by their folded form, then by the raw strings, so equal
/// folds (`Uber`, `Über`) still have one fixed order.
int compareNames(String a, String b) {
  final folded = _folded(a).compareTo(_folded(b));
  return folded != 0 ? folded : a.compareTo(b);
}
