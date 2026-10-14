// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2478 (C2 of #2476) -- the reference snapshot the VAT functions run on and
// the questions they ask of it. A domain function takes a [TaxReferenceSet]
// as an optional PARAMETER; when it is left out, the snapshot the app
// installed at start-up (the bundled copy, then the installation's own rows)
// answers. Nothing here knows a country, a rate or a text: it only resolves
// what the rows say.
import 'tax_reference.dart';

/// The snapshot the app runs on. Installed once at start-up from the bundled
/// copy and replaced when the installation answers; a test installs its own.
abstract final class ActiveTaxReference {
  static TaxReferenceSet? _set;

  /// The installed snapshot; asking before one is installed is a typed
  /// failure, never an empty answer that reads as "no country is in the EU".
  static TaxReferenceSet get current =>
      _set ??
      (throw const TaxReferenceUnavailable('no tax reference data installed'));

  static bool get isInstalled => _set != null;

  static void install(TaxReferenceSet set) => _set = set;
}

/// The questions the VAT code asks of a snapshot. `asOf` is an ISO day: the
/// versions in force on it. Without it the newest version of each value
/// answers (the open-ended one) -- an issued document passes its own day, so
/// a later change of the data never reaches it.
extension TaxReferenceQueries on TaxReferenceSet {
  TaxReferenceSet resolved(String? asOf) => asOf == null
      ? TaxReferenceSet([
          for (final row in rows)
            if (row.validTo == null) row,
        ], origin: origin)
      : on(asOf);

  /// The rows of [domain] that belong to [country] itself (no `*` rows).
  List<TaxReferenceRow> ownRows(TaxDomain domain, String country,
      {String? asOf}) {
    final c = country.trim().toUpperCase();
    return [
      for (final row in resolved(asOf).rows)
        if (row.domain == domain && row.country == c) row,
    ];
  }

  /// The member states of the EU (aliases such as `EL` are not members).
  Set<String> euMembers({String? asOf}) => {
        for (final row in resolved(asOf).where(TaxDomain.euMember))
          if (!(row.value as EuMemberValue).isAlias) row.country,
      };

  /// The canonical code for [code]: trimmed, upper case, an alias row
  /// (`EL` -> `GR`) resolved.
  String euCode(String code, {String? asOf}) {
    final c = code.trim().toUpperCase();
    for (final row in resolved(asOf).where(TaxDomain.euMember, country: c)) {
      final v = row.value as EuMemberValue;
      if (row.country == c && v.isAlias) return v.aliasOf;
    }
    return c;
  }

  bool isEu(String code, {String? asOf}) =>
      euMembers(asOf: asOf).contains(euCode(code, asOf: asOf));

  /// The statutory text of [regime] for [country], the shared `*` text when
  /// the country has none of its own; null when the data holds neither.
  String? mentionFor(String regime, String country, {String? asOf}) {
    final row = resolved(asOf).lookup(TaxDomain.mention, country, regime);
    return (row?.value as ExemptionTextValue?)?.text;
  }

  /// The identifier body a VAT number of [prefix] must have, if one is known.
  String? vatIdBody(String prefix, {String? asOf}) {
    final row = resolved(asOf).lookup(TaxDomain.vatIdPattern, prefix, 'vat_id');
    if (row == null || row.country != prefix.trim().toUpperCase()) return null;
    return (row.value as VatIdPatternValue).pattern;
  }

  /// The issuing terms of a seller in [country] (an alias such as `EL`
  /// resolved); null where the data holds no row, and then the app refuses.
  IssuingGateValue? gateOf(String country, {String? asOf}) {
    final code = euCode(country, asOf: asOf);
    final row = resolved(asOf).lookup(TaxDomain.issuingGate, code, 'gate');
    return row == null || row.country != code ? null : row.value as IssuingGateValue;
  }

  /// Whether the app issues for a seller in [country].
  bool issuesFor(String country, {String? asOf}) =>
      gateOf(country, asOf: asOf)?.issues ?? false;

  /// The countries whose law routes every invoice through a national channel
  /// the app does not speak yet.
  Set<String> nationalChannelCountries({String? asOf}) => {
        for (final row in resolved(asOf).where(TaxDomain.issuingGate))
          if ((row.value as IssuingGateValue).nationalChannelRequired) row.country,
      };
}
