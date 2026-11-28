// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (FIN-09) -- the electronic address schemes (the CEF EAS code list, EN 16931 BT-34 / BT-49 schemeID) a seller
// or a buyer names its e-invoicing address under: picked by name, never typed, and the identifier entered under a
// scheme is checked with that scheme's own shape. The server holds the same list (`public.einvoice_scheme_pattern`,
// migration 0990); test/lint/eas_schemes_parity_test.dart keeps the two equal.

/// One scheme: its EAS [code], the [name] the identifier is known by (with the country whose register issues it, for
/// a national one) and the [pattern] a whole identifier matches.
class EasScheme {
  const EasScheme(this.code, this.name, this.pattern);

  final String code;
  final String name;
  final String pattern;

  /// Whether [identifier], as stored (trimmed), is one of this scheme's.
  bool accepts(String identifier) => RegExp('^(?:$pattern)\$').hasMatch(identifier.trim());
}

/// The schemes offered, in the order of their codes.
const easSchemes = <EasScheme>[
  EasScheme('0002', 'SIREN (FR)', r'[0-9]{9}'),
  EasScheme('0007', 'Organisationsnummer (SE)', r'[0-9]{10}'),
  EasScheme('0009', 'SIRET (FR)', r'[0-9]{14}'),
  EasScheme('0060', 'DUNS', r'[0-9]{9}'),
  EasScheme('0088', 'GLN', r'[0-9]{13}'),
  EasScheme('0106', 'KvK (NL)', r'[0-9]{8}'),
  EasScheme('0151', 'ABN (AU)', r'[0-9]{11}'),
  EasScheme('0183', 'UID (CH)', r'CHE[0-9]{9}'),
  EasScheme('0190', 'OIN (NL)', r'[0-9]{20}'),
  EasScheme('0192', 'Organisasjonsnummer (NO)', r'[0-9]{9}'),
  EasScheme('0201', 'Codice IPA (IT)', r'[A-Z0-9]{6}'),
  EasScheme('0204', 'Leitweg-ID (DE)', r'[0-9]{2,12}(-[A-Z0-9]{1,30})?-[0-9]{2}'),
  EasScheme('0208', 'Numéro d’entreprise (BE)', r'[01][0-9]{9}'),
  EasScheme('0210', 'Codice fiscale (IT)', r'[A-Z0-9]{11}|[A-Z0-9]{16}'),
  EasScheme('0211', 'Partita IVA (IT)', r'[0-9]{11}'),
  EasScheme('0225', 'Annuaire (FR)', r'[0-9]{9}(_[A-Za-z0-9_.+-]{1,100})?'),
  EasScheme('9915', 'UID (AT)', r'ATU[0-9]{8}'),
  EasScheme('9920', 'NIF-IVA (ES)', r'ES[A-Z0-9][0-9]{7}[A-Z0-9]'),
  EasScheme('9925', 'TVA (BE)', r'BE[01][0-9]{9}'),
  EasScheme('9930', 'USt-IdNr. (DE)', r'DE[0-9]{9}'),
  EasScheme('9944', 'BTW (NL)', r'NL[0-9]{9}B[0-9]{2}'),
  EasScheme('9957', 'TVA (FR)', r'FR[A-Z0-9]{2}[0-9]{9}'),
  EasScheme('EM', 'E-mail', r'[^@\s]+@[^@\s]+\.[^@\s]+'),
];

/// The scheme of [code], or null for one not offered.
EasScheme? easSchemeOf(String code) {
  final c = code.trim().toUpperCase();
  for (final s in easSchemes) {
    if (s.code == c) return s;
  }
  return null;
}

/// Why an address of [identifier] under [scheme] cannot be stored, or null when it can: both empty is no address;
/// an address keeps its scheme; a scheme is one offered, and the identifier one of its shape. An address stored as
/// [storedScheme] : [storedIdentifier] is kept as it was, even under a scheme no longer offered.
EasRefusal? easAddressRefusal(
  String scheme,
  String identifier, {
  String storedScheme = '',
  String storedIdentifier = '',
}) {
  final s = scheme.trim().toUpperCase();
  final id = identifier.trim();
  if (id.isEmpty) return null;
  if (s == storedScheme.trim().toUpperCase() && id == storedIdentifier.trim()) return null;
  if (s.isEmpty) return EasRefusal.scheme;
  final known = easSchemeOf(s);
  if (known == null) return EasRefusal.scheme;
  return known.accepts(id) ? null : EasRefusal.identifier;
}

/// What is wrong with an address.
enum EasRefusal {
  /// No scheme, or one not offered.
  scheme,

  /// The identifier is not of the scheme's shape.
  identifier,
}
