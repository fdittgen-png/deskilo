// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- each feature owns the words of its refusal codes. Core keeps the
// families every screen can meet (refusal_text.dart: who may, who you are,
// it already happened, it moved); a feature registers the table of its own
// codes here once, at start, and `knownRefusalText` asks the tables in turn.
// Core names no feature's code.
import '../../l10n/app_localizations.dart';

/// The sentence for a refusal [code] a feature owns, with the refusal's
/// [details] (the server's JSON detail, when it said one), or null when the
/// code is not the feature's.
typedef RefusalWords = String? Function(
  AppLocalizations l10n,
  String code,
  String? details,
);

/// The page of the app a refusal [code] points to (the stock of the item a
/// sale was refused for), or null.
typedef RefusalLink = String? Function(String code, String? details);

/// The registered tables, in the order they were registered.
abstract final class FeatureRefusals {
  static final List<RefusalWords> _words = [];
  static final List<RefusalLink> _links = [];

  /// Adds a feature's table; registering the same function again changes
  /// nothing.
  static void register(RefusalWords words, {RefusalLink? link}) {
    if (!_words.contains(words)) _words.add(words);
    if (link != null && !_links.contains(link)) _links.add(link);
  }

  /// The first registered table's sentence for [code].
  static String? wordsFor(AppLocalizations l10n, String code, String? details) {
    for (final words in _words) {
      final said = words(l10n, code, details);
      if (said != null) return said;
    }
    return null;
  }

  /// The first registered table's page for [code].
  static String? linkFor(String code, String? details) {
    for (final link in _links) {
      final page = link(code, details);
      if (page != null) return page;
    }
    return null;
  }
}
