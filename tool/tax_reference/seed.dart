// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 — the seed of the tax reference store, READ from the Dart
// constants it replaces, never retyped: `vat_catalogue.dart` (rates, their
// dates and exemption reasons), `place_of_supply.dart` (the EU members) and
// `vat_compliance.dart` (the statutory mentions and the VAT id patterns).
// The same rows feed the seed block of the migration and the copy the app
// ships in `assets/instance/tax_reference.json`, so the two cannot differ.
import 'dart:convert';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';

/// One seed row (the table's `id` and system columns are the server's).
typedef SeedRow = ({
  String domain,
  String country,
  String key,
  String validFrom,
  Map<String, Object?> value,
  String source,
  bool confirmed,
});

/// The catalogue header's own claim: "Verified 2026-08 against the Tax
/// Foundation EU table + skatteetaten.no + estv.admin.ch + CRA".
const _verifiedSource =
    'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation '
    'EU table, skatteetaten.no, estv.admin.ch and CRA';
const _gbSource =
    'vat_catalogue.dart (#2359): VAT Act 1994; not re-verified since the '
    'catalogue was written';
const _statuteSource =
    'vat_catalogue.dart (#2359, #2360): the statutory reason of the exempt '
    'line; typed in code, not re-verified';
const _mentionSource =
    'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the '
    'member state\'s own law; typed in code, not re-verified';
const _patternSource =
    'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the '
    'identifier body; typed in code, not re-verified';
const _euSource =
    'place_of_supply.dart (#2354): the member states of the European Union';

/// The countries a mention may differ for: the catalogue's countries plus
/// the EU set (a mention of a country outside both falls to the default).
Set<String> _countries() => {...vatCatalogueCountries, ...euMemberStates};

/// Every seed row, sorted by domain, country, key and validity.
List<SeedRow> buildTaxReferenceSeed() {
  final rows = <SeedRow>[
    ..._rates(),
    ..._euMembers(),
    ..._mentions(),
    ..._idPatterns(),
  ]..sort((a, b) {
      final byDomain = a.domain.compareTo(b.domain);
      if (byDomain != 0) return byDomain;
      final byCountry = a.country.compareTo(b.country);
      if (byCountry != 0) return byCountry;
      final byKey = a.key.compareTo(b.key);
      return byKey != 0 ? byKey : a.validFrom.compareTo(b.validFrom);
    });
  return rows;
}

Iterable<SeedRow> _rates() sync* {
  for (final country in vatCatalogueCountries) {
    final rates = vatCatalogueFor(country);
    final perGroup = <String, int>{};
    for (final r in rates) {
      perGroup.update(r.groupKey, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final (index, r) in rates.indexed) {
      // A group with one rate is keyed by the group (a rate change by law
      // is a new VERSION of that key); several in a group (Canada's
      // provincial rates) are keyed by group and percent.
      final key = perGroup[r.groupKey]! > 1
          ? '${r.groupKey}-${_percent(r)}'
          : r.groupKey;
      final verified = country != 'GB' && r.exemptionReason.isEmpty;
      yield (
        domain: 'rate',
        country: country,
        key: key,
        validFrom: r.validFrom,
        value: RateValue(
          label: r.label,
          percent: r.percent,
          group: r.groupKey,
          category: r.category,
          exemptionReason: r.exemptionReason,
          position: index,
        ).toJson(),
        source: r.exemptionReason.isNotEmpty
            ? _statuteSource
            : country == 'GB'
                ? _gbSource
                : _verifiedSource,
        confirmed: verified,
      );
    }
  }
}

String _percent(VatRate r) => r.percent == r.percent.truncateToDouble()
    ? r.percent.toInt().toString()
    : r.percent.toString();

Iterable<SeedRow> _euMembers() sync* {
  for (final country in euMemberStates) {
    yield (
      domain: 'eu_member',
      country: country,
      key: 'member',
      validFrom: taxReferenceEpoch,
      value: const EuMemberValue().toJson(),
      source: _euSource,
      confirmed: true,
    );
  }
}

/// A country gets its own row for a regime only where its mention differs
/// from the one every other country prints (the `*` row).
Iterable<SeedRow> _mentions() sync* {
  const probe = 'ZZ';
  final texts = <String, String Function(String country)>{
    'exempt': (c) => defaultExemptionMention(c, VatRegime.exempt),
    'not_subject': (c) => defaultExemptionMention(c, VatRegime.notSubject),
    'reverse_charge': reverseChargeMention,
    'export': exportMention,
    'exigibility_receipts': (c) => exigibilityMention(
        regime: VatRegime.vatRegistered, sellerCountry: c, onPaymentBasis: true),
    'exigibility_invoices': (c) => exigibilityMention(
        regime: VatRegime.vatRegistered, sellerCountry: c, onPaymentBasis: false),
  };
  for (final MapEntry(key: regime, value: text) in texts.entries) {
    final shared = text(probe);
    yield (
      domain: 'exemption_text',
      country: taxReferenceAnyCountry,
      key: regime,
      validFrom: taxReferenceEpoch,
      value: ExemptionTextValue(regime: regime, text: shared).toJson(),
      source: _mentionSource,
      confirmed: false,
    );
    for (final country in _countries()) {
      final own = text(country);
      if (own == shared) continue;
      yield (
        domain: 'exemption_text',
        country: country,
        key: regime,
        validFrom: taxReferenceEpoch,
        value: ExemptionTextValue(regime: regime, text: own).toJson(),
        source: _mentionSource,
        confirmed: false,
      );
    }
  }
}

Iterable<SeedRow> _idPatterns() sync* {
  for (final MapEntry(key: country, value: pattern)
      in vatIdBodiesForSeed.entries) {
    yield (
      domain: 'vat_id_pattern',
      country: country,
      key: 'vat_id',
      validFrom: taxReferenceEpoch,
      value: VatIdPatternValue(pattern: pattern).toJson(),
      source: _patternSource,
      confirmed: false,
    );
  }
}

String _q(String s) => "'${s.replaceAll("'", "''")}'";

/// The `insert` of the migration's seed block, one row per line.
String taxReferenceSeedSql(List<SeedRow> rows) {
  final lines = [
    for (final r in rows)
      '(${_q(r.domain)}, ${_q(r.country)}, ${_q(r.key)}, ${_q(r.validFrom)}, '
          '${_q(jsonEncode(r.value))}::jsonb, ${_q(r.source)}, ${r.confirmed})',
  ];
  return 'insert into public.tax_reference\n'
      '  (domain, country, key, valid_from, value, source, confirmed)\n'
      'values\n${lines.join(',\n')}\n'
      'on conflict (domain, country, key, valid_from) do nothing;';
}

const seedBegin = '-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)';
const seedEnd = '-- END GENERATED SEED';

/// [migration] with its seed block replaced by the current seed.
String withTaxReferenceSeed(String migration, List<SeedRow> rows) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) {
    throw StateError('the migration has no seed block between "$seedBegin" '
        'and "$seedEnd"');
  }
  return '${migration.substring(0, start)}$seedBegin\n'
      '${taxReferenceSeedSql(rows)}\n${migration.substring(end)}';
}

/// The seed block of [migration], as written.
String? seedBlockOf(String migration) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) return null;
  return migration.substring(start + seedBegin.length + 1, end - 1);
}

/// The app's offline copy: one row per line, sorted, so two pull requests
/// that add different rows merge without a conflict.
String taxReferenceBundleJson(List<SeedRow> rows) {
  final lines = [
    for (final r in rows)
      jsonEncode({
        'domain': r.domain,
        'country': r.country,
        'key': r.key,
        'valid_from': r.validFrom,
        'valid_to': null,
        'value': r.value,
        'source': r.source,
        'confirmed': r.confirmed,
      }),
  ];
  return '[\n${lines.join(',\n')}\n]\n';
}
