// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../l10n/app_localizations.dart';

/// Independent facts on one line, `first · second · third`: each is already a
/// whole text, the separator is ONE message (`dotPair`) so a language may
/// change it, and an absent or empty fact leaves no dangling separator
/// (#3767). Not a way to build a sentence: a fact that needs a word of its
/// own in front of a value is a message of its own.
String factLine(AppLocalizations l10n, Iterable<String?> facts) {
  String? line;
  for (final fact in facts) {
    if (fact == null || fact.isEmpty) continue;
    line = line == null ? fact : l10n.dotPair(line, fact);
  }
  return line ?? '';
}
