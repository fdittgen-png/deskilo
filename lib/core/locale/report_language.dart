// SPDX-License-Identifier: 0BSD

/// Report-language resolution (#496): which language a DOCUMENT is
/// printed in for a given reader.
///
/// The chain, in order:
///  1. the MEMBER's own preferred language (profiles.preferred_locale,
///     0098) — when the app supports it;
///  2. the WORKSPACE language (workspaces.default_locale, 0096);
///  3. the COUNTRY's language — unambiguous countries only. A
///     multi-language country (Belgium, Switzerland, Luxembourg,
///     Canada) with nothing configured RAISES
///     [AmbiguousReportLanguage]: the app must not guess between an
///     invoice in French and one in German.
///
/// Per-language template OVERLAYS (the owner's "specialized languages")
/// are resolved by the template model itself; this file only decides
/// WHICH language a document targets.
library;

/// The languages the app ships documents in.
const Set<String> supportedReportLanguages = {'en', 'fr', 'de', 'es', 'it'};

/// Countries whose national language is ambiguous — the workspace must
/// declare its own language before language-resolved documents render.
const Set<String> multiLanguageCountries = {'BE', 'CH', 'LU', 'CA'};

/// The single app-supported language of [countryCode], null when the
/// country is multi-language, 'en' when its language is one the app
/// does not ship (an English document beats a guessed one).
String? countryLanguage(String countryCode) {
  final code = countryCode.toUpperCase();
  if (multiLanguageCountries.contains(code)) return null;
  const byCountry = {
    'FR': 'fr', 'MC': 'fr',
    'DE': 'de', 'AT': 'de', 'LI': 'de',
    'ES': 'es', 'MX': 'es', 'AR': 'es', 'CL': 'es', 'CO': 'es',
    'IT': 'it', 'SM': 'it',
    'GB': 'en', 'IE': 'en', 'US': 'en', 'AU': 'en', 'NZ': 'en',
  };
  return byCountry[code] ?? 'en';
}

/// Thrown when the chain bottoms out on a multi-language country with
/// no member and no workspace language configured.
class AmbiguousReportLanguage implements Exception {
  const AmbiguousReportLanguage(this.countryCode);

  final String countryCode;

  @override
  String toString() =>
      'AmbiguousReportLanguage: $countryCode has several languages — '
      'set the workspace language.';
}

/// Resolves the document language for a reader.
///
/// [memberLocale] — the member's preferred language ('' = unset);
/// [workspaceLocale] — the workspace's own language ('' = unset);
/// [countryCode] — the workspace's country, the last resort.
String resolveReportLanguage({
  String memberLocale = '',
  String workspaceLocale = '',
  required String countryCode,
}) {
  if (supportedReportLanguages.contains(memberLocale)) return memberLocale;
  if (supportedReportLanguages.contains(workspaceLocale)) {
    return workspaceLocale;
  }
  final country = countryLanguage(countryCode);
  if (country == null) throw AmbiguousReportLanguage(countryCode);
  return country;
}
