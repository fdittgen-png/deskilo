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
import '../../../core/data/json_reader.dart';
import 'accounting_amount.dart';

/// One tax inside a rate: its scheme (`GST`, `HST`, `QST`, `PST`), who
/// levies it (`CA`, `CA-QC`, `CA-PST`) and its own percentage.
typedef _ComponentRate = ({String scheme, String authority, double percent});

/// The components of a combined [percent] charged by a seller in [country],
/// or an empty list when the rate is not split (every country but Canada,
/// and a Canadian rate the catalogue does not know).
List<_ComponentRate> _componentRates(String country, double percent) {
  if (country.trim().toUpperCase() != 'CA') return const [];
  const gst = (scheme: 'GST', authority: 'CA', percent: 5.0);
  return switch (percent) {
    5.0 => const [gst],
    13.0 || 14.0 || 15.0 => [(scheme: 'HST', authority: 'CA', percent: percent)],
    14.975 => const [
      gst,
      (scheme: 'QST', authority: 'CA-QC', percent: 9.975),
    ],
    // Legacy "GST+PST" rows: honest about what they charge.
    12.0 => const [gst, (scheme: 'PST', authority: 'CA-PST', percent: 7.0)],
    11.0 => const [gst, (scheme: 'PST', authority: 'CA-PST', percent: 6.0)],
    _ => const [],
  };
}

/// One tax of an invoice total, as frozen at issue.
class VatComponent {
  const VatComponent({
    required this.scheme,
    required this.authority,
    required this.percent,
    required this.baseCents,
    required this.taxCents,
  });

  final String scheme;
  final String authority;
  final double percent;

  /// The amount the tax is levied on (the price without the GST).
  final int baseCents;
  final int taxCents;

  Map<String, Object?> toJson() => {
        'scheme': scheme,
        'authority': authority,
        'percent': percent,
        'base_cents': baseCents,
        'tax_cents': taxCents,
      };

  factory VatComponent.fromReader(JsonReader r) {
    return VatComponent(
      scheme: r.stringOr('scheme'),
      authority: r.stringOr('authority'),
      percent: r.doubleOrNull('percent') ?? 0,
      baseCents: r.intOrNull('base_cents') ?? 0,
      taxCents: r.intOrNull('tax_cents') ?? 0,
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
  int vatCents,
) {
  final rates = _componentRates(country, percent);
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
