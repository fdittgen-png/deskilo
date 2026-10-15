// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';

/// #2440 — when the turnover of an exempt (small-business) seller leaves
/// the exemption.
enum ThresholdEffect {
  /// The exemption ends with the year in which the figure is passed.
  nextYear,

  /// The exemption ends at once, on the supply that passes the figure.
  immediate,
}

/// One row of the data: a country, a net turnover in euro cents and what
/// passing it does. A row is data, not logic — a change of law is a new
/// row, with its source named here.
class SmallBusinessThreshold {
  const SmallBusinessThreshold({
    required this.country,
    required this.cents,
    required this.effect,
    required this.source,
    this.confirmed = true,
  });

  final String country;
  final int cents;
  final ThresholdEffect effect;
  final String source;

  /// False when the figure is the last one the project could verify and
  /// the law of the running year may have moved it (see the FR rows).
  final bool confirmed;
}

/// #2478/#2479 -- the thresholds are rows of the tax reference store
/// (`threshold`, key `small_business_<effect>`), in minor units of NET
/// turnover, each with its source and whether somebody confirmed it.
///
/// Germany -- § 19 Abs. 1 UStG as worded by the Jahressteuergesetz 2024
/// (BGBl. 2024 I Nr. 387), in force since 2025-01-01: the Kleinunternehmer
/// regime applies while the turnover of the PREVIOUS year did not pass
/// € 25 000 and the turnover of the RUNNING year does not pass € 100 000.
/// France -- CGI art. 293 B (franchise en base de TVA), services, with a
/// tolerance within the year; the 2026 figure was NOT verified, so those
/// rows are unconfirmed and an owner is told to check them.
List<SmallBusinessThreshold> _thresholdsOf(
  String country,
  String currency,
  TaxReferenceSet set,
) =>
    [
      for (final row in set.where(TaxDomain.threshold, country: country))
        if (row.country == country &&
            (row.value as ThresholdValue).currency == currency)
          SmallBusinessThreshold(
            country: row.country,
            cents: (row.value as ThresholdValue).cents,
            effect: (row.value as ThresholdValue).effect == 'immediate'
                ? ThresholdEffect.immediate
                : ThresholdEffect.nextYear,
            source: row.source,
            confirmed: row.confirmed,
          ),
    ];

/// Where a turnover stands against one row.
enum ThresholdLevel { near, passed }

class SmallBusinessAlert {
  const SmallBusinessAlert({
    required this.threshold,
    required this.level,
    required this.turnoverCents,
  });

  final SmallBusinessThreshold threshold;
  final ThresholdLevel level;
  final int turnoverCents;
}

/// A turnover from this share of a threshold on is "near".
const _nearShare = 0.8;

/// The net turnover issued in [year]: invoices not voided, without the
/// settlements that merely regroup invoices already counted.
int turnoverOfYear(Iterable<Invoice> invoices, int year) => invoices
    .where((i) => i.issuedAt.year == year && !i.isVoided && i.settles.isEmpty)
    .fold(0, (sum, i) => sum + i.netCents);

/// What an exempt seller of [country] must be told about [turnoverCents]
/// of the running year: one alert per row reached, the highest first. None
/// outside the rows' countries or for any currency but the euro.
List<SmallBusinessAlert> smallBusinessAlerts({
  required String country,
  required String currency,
  required int turnoverCents,
  String? asOf,
  TaxReferenceSet? reference,
}) {
  final rows = _thresholdsOf(
    country.trim().toUpperCase(),
    currency.toUpperCase(),
    (reference ?? ActiveTaxReference.current).resolved(asOf),
  )..sort((a, b) => b.cents.compareTo(a.cents));
  return [
    for (final t in rows)
      if (turnoverCents >= t.cents)
        SmallBusinessAlert(
          threshold: t,
          level: ThresholdLevel.passed,
          turnoverCents: turnoverCents,
        )
      else if (turnoverCents >= t.cents * _nearShare)
        SmallBusinessAlert(
          threshold: t,
          level: ThresholdLevel.near,
          turnoverCents: turnoverCents,
        ),
  ];
}
