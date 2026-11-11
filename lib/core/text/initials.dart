// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3654 -- the initials of a name are taken on grapheme clusters, never on
// code units: "Émile" written as E + a combining accent, a name that starts
// with an emoji or a flag, "李雷" -- each gives one whole character, not half
// of one.
import 'package:characters/characters.dart';

/// The first whole character of [name], upper-cased; "?" for a blank name.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

/// Up to two initials of [name] (the first letters of its first two words),
/// for the avatar of a row without a photo; "?" for a blank name.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = [for (final w in words.take(2)) w.characters.first.toUpperCase()];
  return letters.isEmpty ? '?' : letters.join();
}
