// SPDX-License-Identifier: AGPL-3.0-or-later
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

/// The thresholds, in euro cents of NET turnover.
///
/// Germany — § 19 Abs. 1 UStG as worded by the Jahressteuergesetz 2024
/// (BGBl. 2024 I Nr. 387), in force since 2025-01-01: the Kleinunternehmer
/// regime applies while the turnover of the PREVIOUS year did not pass
/// € 25 000 and the turnover of the RUNNING year does not pass € 100 000;
/// passing € 100 000 ends it on that very supply.
///
/// France — CGI art. 293 B (franchise en base de TVA), services: € 37 500,
/// with a tolerance up to € 41 250 within the year (passing the tolerance
/// ends the franchise at once, passing only the base figure ends it with
/// the year). These are the figures of the 2023-2025 revaluation. The
/// reform of the loi de finances 2025 (a single € 25 000 threshold from
/// 2025-03-01) was suspended and the loi de finances 2026 reopened the
/// matter; the 2026 figure was NOT verified here, so the rows are marked
/// unconfirmed and an owner is told to check them (the warning says so).
/// When the figure is confirmed, change the rows — nothing else.
const _thresholds = <SmallBusinessThreshold>[
  SmallBusinessThreshold(
    country: 'DE',
    cents: 2500000,
    effect: ThresholdEffect.nextYear,
    source: '§ 19 Abs. 1 UStG (JStG 2024)',
  ),
  SmallBusinessThreshold(
    country: 'DE',
    cents: 10000000,
    effect: ThresholdEffect.immediate,
    source: '§ 19 Abs. 1 UStG (JStG 2024)',
  ),
  SmallBusinessThreshold(
    country: 'FR',
    cents: 3750000,
    effect: ThresholdEffect.nextYear,
    source: 'CGI art. 293 B (services)',
    confirmed: false,
  ),
  SmallBusinessThreshold(
    country: 'FR',
    cents: 4125000,
    effect: ThresholdEffect.immediate,
    source: 'CGI art. 293 B (services, tolerance)',
    confirmed: false,
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
}) {
  if (currency.toUpperCase() != 'EUR') return const [];
  final code = country.trim().toUpperCase();
  final rows = [
    for (final t in _thresholds)
      if (t.country == code) t,
  ]..sort((a, b) => b.cents.compareTo(a.cents));
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
