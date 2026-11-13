// SPDX-License-Identifier: AGPL-3.0-or-later

/// Report-language resolution (#496, #3850): which language a DOCUMENT is
/// printed in.
///
/// The chain, in order:
///  1. the reader's own language (a member's `preferred_locale`, 0098), when
///     the app ships it -- for letters to a person; an INVOICE carries the
///     language the server froze at issue instead (`invoices.document_language`);
///  2. the business's document language (`workspaces.default_locale`, 0096);
///  3. the country's first shipped language, from its `document_language`
///     row of the tax reference store (#3850);
///  4. English, where the country's languages are none the app ships.
///
/// It never throws: a country with several shipped languages and none chosen
/// takes its first (the server gave every such business a language, 0753).
/// Per-language template OVERLAYS are resolved by the template model itself;
/// this file only decides WHICH language a document targets.
library;

/// The languages the app ships documents in (the server's
/// `document_language_supported`, 0753).
const Set<String> documentLanguagesShipped = {'en', 'fr', 'de', 'es', 'it'};

/// The language a document falls back to when nothing else applies.
const String _fallback = 'en';

/// The shipped languages among a country's official [languages], in order.
List<String> _shipped(List<String> languages) => [
      for (final l in languages)
        if (documentLanguagesShipped.contains(l)) l,
    ];

/// Whether a business of a country with these [languages] must choose its
/// document language (more than one shipped).
bool choosesDocumentLanguage(List<String> languages) =>
    _shipped(languages).length > 1;

/// The business's document language: its own [workspaceLocale] when shipped,
/// else the first shipped of its country's [countryLanguages], else English.
String businessDocumentLanguage({
  String workspaceLocale = '',
  required List<String> countryLanguages,
}) {
  if (documentLanguagesShipped.contains(workspaceLocale)) return workspaceLocale;
  return _shipped(countryLanguages).firstOrNull ?? _fallback;
}

/// Resolves the document language for a reader.
///
/// [memberLocale] -- the reader's preferred language ('' = unset);
/// [workspaceLocale] -- the business's document language ('' = unset);
/// [countryLanguages] -- its country's official languages, usual one first.
String resolveReportLanguage({
  String memberLocale = '',
  String workspaceLocale = '',
  required List<String> countryLanguages,
}) {
  if (documentLanguagesShipped.contains(memberLocale)) return memberLocale;
  return businessDocumentLanguage(
    workspaceLocale: workspaceLocale,
    countryLanguages: countryLanguages,
  );
}
