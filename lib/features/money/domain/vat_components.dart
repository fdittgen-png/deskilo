// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2361 — the tax of a Canadian invoice as COMPONENTS, not a sum.
//
// A Quebec invoice states the GST and the QST as two amounts (ETA s.
// 169(4); the Act respecting the QST, s. 425). Both are levied on the price
// excluding GST — the QST has not compounded on the GST since 2013 — so the
// combined 14.975 % of the catalogue is the exact sum of 5 + 9.975 on the
// same base: the total of the invoice does not move, only what it shows.
//
// The server twin is `vat_percent_components` / `vat_components_entry`
// (migration 0423, pgTAP 180) and freezes the result in `vat_totals`;
// this file reads it back and computes the same split for the issue preview.
// #2539 -- the split itself is DATA: `rate_component` rows of the tax
// reference store (the server twin reads the same table), not a table here.
import '../../../core/data/json_reader.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'accounting_amount.dart';

/// The components of a combined [percent] charged by a seller in [country],
/// or an empty list when the rate is not split (a country with no
/// `rate_component` row for it, and a rate the data does not know). The rows
/// of the tax reference store are the only copy: the server twin
/// `vat_percent_components` reads the same table.
List<RateComponent> _componentRates(
  String country,
  double percent,
  String? asOf,
  TaxReferenceSet? reference,
) {
  final set = reference ?? ActiveTaxReference.current;
  for (final row in set.ownRows(TaxDomain.rateComponent, country, asOf: asOf)) {
    final value = row.value as RateComponentValue;
    if ((value.percent - percent).abs() < 1e-9) return value.components;
  }
  return const [];
}

/// One tax of an invoice total, as frozen at issue.
class VatComponent {
  const VatComponent({
    required this.scheme,
    required this.authority,
    required this.percent,
    required this.baseCents,
    required this.taxCents,
    this.name = '',
    this.level = '',
  });

  final String scheme;
  final String authority;
  final double percent;

  /// #2362 — the jurisdiction a sales tax is levied by ('New York City') and
  /// its level (state, county, city, district); '' on a GST / HST / QST.
  final String name;
  final String level;

  /// The amount the tax is levied on (the price without the GST).
  final int baseCents;
  final int taxCents;

  Map<String, Object?> toJson() => {
        'scheme': scheme,
        'authority': authority,
        'percent': percent,
        'base_cents': baseCents,
        'tax_cents': taxCents,
        if (name.isNotEmpty) 'name': name,
        if (level.isNotEmpty) 'level': level,
      };

  factory VatComponent.fromReader(JsonReader r) {
    return VatComponent(
      scheme: r.stringOr('scheme'),
      authority: r.stringOr('authority'),
      percent: r.doubleOrNull('percent') ?? 0,
      baseCents: r.intOrNull('base_cents') ?? 0,
      taxCents: r.intOrNull('tax_cents') ?? 0,
      name: r.stringOr('name'),
      level: r.stringOr('level'),
    );
  }
}

/// The components of a total of [netCents] and [vatCents] at [percent]: each
/// one rounded on the net (half away from zero, as the server's `round`),
/// the last taking the remainder so they always add up to [vatCents].
List<VatComponent> vatComponentsOf(
  String country,
  double percent,
  int netCents,
  int vatCents, {
  String? asOf,
  TaxReferenceSet? reference,
}) {
  final rates = _componentRates(country, percent, asOf, reference);
  var left = vatCents;
  return [
    for (final (index, rate) in rates.indexed)
      () {
        final tax = index == rates.length - 1
            ? left
            : _share(netCents, rate.percent);
        left -= tax;
        return VatComponent(
          scheme: rate.scheme,
          authority: rate.authority,
          percent: rate.percent,
          baseCents: netCents,
          taxCents: tax,
        );
      }(),
  ];
}

int _share(int netCents, double percent) {
  final rate = ExactDecimal.parse(percent.toString());
  return AccountingAmount('EUR', 1).roundedQuotient(
    BigInt.from(netCents) * rate.units,
    BigInt.from(100) * rate.denominator,
    RoundingPolicy.halfUp,
  );
}

/// The name a tax goes by on a document in [locale]: the federal and Quebec
/// acronyms are French in French (TPS, TVH, TVQ, TVP) and the English ones
/// everywhere else, as Canadian invoices print them.
String taxSchemeName(String scheme, String locale) {
  if (!locale.toLowerCase().startsWith('fr')) return scheme;
  return switch (scheme) {
    'GST' => 'TPS',
    'HST' => 'TVH',
    'QST' => 'TVQ',
    'PST' => 'TVP',
    _ => scheme,
  };
}
