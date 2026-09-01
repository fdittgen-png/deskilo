// SPDX-License-Identifier: 0BSD

/// #793 — the letters in an avatar circle must name ONE person.
///
/// A workspace with Mathieu, mathieu.bouchard and marion.blein.gauthier
/// drew three identical `M` circles, so the fallback glyph — the thing
/// shown for every member who never uploaded a photo — identified
/// nobody. The rule the owner asked for, and what it means here:
///
///  1. the first letters of the first name AND the family name (`MB`);
///  2. on a clash, take the next letter of the family name (`MBo`);
///  3. when even that is taken, count (`MB2`, `MB3`, …).
///
/// Names in this app are rarely two tidy words — they arrive as
/// `mathieu.bouchard`, `marion.blein.gauthier`, `flo1` or a bare
/// `Guilhem` — so the "first name" is the first token and the "family
/// name" is the LAST one, split on the separators people actually type.
/// A single token has no family name, so it starts at one letter and
/// grows through itself: `F`, `FL`, `FLO`.
library;

/// Longest monogram this will letter its way up to. Past this the
/// numbers take over: four glyphs in a small circle stop being readable,
/// and the ladder must terminate somewhere.
const int _maxLetters = 3;

/// First [n] characters of [s], counted in runes so a name starting
/// with an astral glyph is not cut in half.
String _take(String s, int n) => String.fromCharCodes(s.runes.take(n));

int _runeLength(String s) => s.runes.length;

/// Splits a display name into its tokens on whitespace, dots, hyphens,
/// underscores and the middle dot — everything a name arrives glued
/// together with — keeping only alphanumerics.
List<String> _tokens(String name) => name
    .split(RegExp(r'[\s._\-·]+'))
    .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
    .where((t) => t.isNotEmpty)
    .toList(growable: false);

/// The ladder of monograms [name] would like, best first.
///
/// Deliberately finite: the caller falls back to numbering when a whole
/// ladder is taken, which is what guarantees the result is unique no
/// matter how many people share a name.
List<String> monogramLadder(String name) {
  final tokens = _tokens(name);
  if (tokens.isEmpty) return const ['?'];
  final head = tokens.first.toUpperCase();

  if (tokens.length == 1) {
    // No family name: grow through the one token — F, FL, FLO.
    return [
      for (var n = 1; n <= _maxLetters && n <= _runeLength(head); n++)
        _take(head, n),
    ];
  }

  final family = tokens.last.toUpperCase();
  return [
    // MB, then MBo-style extensions one family letter at a time.
    for (var n = 1; n <= _maxLetters - 1 && n <= _runeLength(family); n++)
      _take(head, 1) + _take(family, n),
  ];
}

/// Unique monograms for [names], keyed the same way [names] is.
///
/// Assignment is FIRST COME, FIRST SERVED (#793): [order] gives each key
/// its join instant, and a member who joined earlier keeps the letters
/// they were given no matter who arrives later. Without it the sort
/// falls back to the name, which is deterministic but not stable — a new
/// member whose name sorted earlier would take an existing member's
/// monogram and hand them a longer one.
///
/// Ties (and members with no recorded join) break on the key, so two
/// devices always compute the same answer for the same workspace.
///
/// Only names whose ladders actually COLLIDE are affected: `Mathieu`
/// keeps `M` and `mathieu.bouchard` takes `MB` because those are their
/// first choices, not because anything was resolved between them.
Map<String, String> assignMonograms(
  Map<String, String> names, {
  Map<String, DateTime?> order = const {},
}) {
  final entries = names.entries.toList()
    ..sort((a, b) {
      final aJoined = order[a.key];
      final bJoined = order[b.key];
      if (aJoined != null && bJoined != null && aJoined != bJoined) {
        return aJoined.compareTo(bJoined);
      }
      // A known join always precedes an unknown one: the member who can
      // prove they were here first is the one who keeps their letters.
      if (aJoined != null && bJoined == null) return -1;
      if (aJoined == null && bJoined != null) return 1;
      final byName =
          a.value.toLowerCase().compareTo(b.value.toLowerCase());
      return byName != 0 ? byName : a.key.compareTo(b.key);
    });

  final taken = <String>{};
  final result = <String, String>{};
  for (final entry in entries) {
    final ladder = monogramLadder(entry.value);
    var chosen = ladder.firstWhere(
      (candidate) => !taken.contains(candidate),
      orElse: () => '',
    );
    if (chosen.isEmpty) {
      // Every letter form is spoken for: count from the name's FIRST
      // choice, which keeps the numbered ones recognisable as the
      // family they belong to (MB2, MB3 — not X7).
      final base = ladder.first;
      for (var n = 2;; n++) {
        if (taken.add('$base$n')) {
          chosen = '$base$n';
          break;
        }
      }
    } else {
      taken.add(chosen);
    }
    result[entry.key] = chosen;
  }
  return result;
}

/// The single letter the avatar showed before uniqueness existed — the
/// fallback for anyone the workspace's member list does not cover (a
/// former member on an old message, a kiosk receipt mid-load) and for
/// workspaces with the feature switched off.
String plainInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : _take(trimmed, 1).toUpperCase();
}
