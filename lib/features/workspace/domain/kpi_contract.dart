// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the one KPI contract, and its first metric.
//
// A KPI is a definition with a stable id and version, a unit, a time
// basis, the dimensions it may be cut by, its numerator and denominator,
// how it aggregates, who may read it and what its data must satisfy. The
// SERVER computes it (`kpi_seat_capacity`); this layer names what the
// server returns and turns it into a typed answer. A ratio is always
// sum(numerator) / sum(denominator) — never the mean of child ratios —
// and a zero denominator is undefined, not 0 %.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'dart:convert';

/// How a KPI may be combined across a dimension or across time.
enum KpiAggregation {
  /// sum(numerator) / sum(denominator) over the whole scope.
  ratioOfSums,

  /// Additive over disjoint intervals and resources.
  sum,
}

/// #1921 — what a KPI discloses, and so who may read it.
enum KpiDisclosure {
  /// Counts and hours over places and time; no person, no money.
  aggregateOperational,

  /// Amounts: also needs viewFinances.
  financial,

  /// Figures about identifiable people: also needs viewPersonalData and a
  /// minimum cohort.
  personalOperational,

  /// The reader's own figures.
  own;

  /// The wire name the server registry uses.
  String get wire => switch (this) {
    aggregateOperational => 'aggregate_operational',
    financial => 'financial',
    personalOperational => 'personal_operational',
    own => 'own',
  };
}

/// One registered KPI definition.
class KpiDefinition {
  const KpiDefinition({
    required this.id,
    required this.version,
    required this.unit,
    required this.timeBasis,
    required this.dimensions,
    required this.numerator,
    required this.denominator,
    required this.aggregation,
    required this.permissions,
    required this.disclosure,
    required this.prerequisites,
    this.minCohort,
  });

  final String id;
  final int version;
  final String unit;

  /// What the interval means: `[from, to)` in UTC, buckets in the
  /// workspace's time zone.
  final String timeBasis;
  final List<String> dimensions;
  final String numerator;
  final String denominator;
  final KpiAggregation aggregation;

  /// The `WorkspacePermission` wire names the server requires, all of
  /// them (#1921). Finance needs viewFinances, people viewPersonalData;
  /// exportData alone never reads.
  final List<String> permissions;

  /// What the figure discloses (#1921).
  final KpiDisclosure disclosure;

  /// For a figure about people: the smallest group the server may
  /// report. Required for [KpiDisclosure.personalOperational].
  final int? minCohort;
  final List<String> prerequisites;
}

/// Seat utilisation: reserved seat-hours over offered seat-hours.
const seatUtilisationKpi = KpiDefinition(
  id: 'capacity.seat_utilisation',
  version: 1,
  unit: 'percent',
  timeBasis:
      'reservation time within opening hours, [from, to) UTC, '
      'days and opening hours in the workspace time zone',
  dimensions: ['level'],
  numerator: 'reserved_seat_hours',
  denominator: 'offered_seat_hours',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics'],
  disclosure: KpiDisclosure.aggregateOperational,
  prerequisites: [
    'opening weekdays and hours (booking rules)',
    'closure days',
    'seat blocks',
  ],
);

/// #1924 — what was invoiced over whole workspace months: invoices of
/// the months, non-void, settlements left out (they regroup invoices
/// already counted), positive totals. Credit notes are named beside it,
/// never netted silently. Not a profit: no cost is in it.
const invoicedKpi = KpiDefinition(
  id: 'finance.invoiced',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the invoice\'s month (YYYY-MM), whole months [from, to] on the '
      'workspace calendar',
  dimensions: [],
  numerator: 'invoiced_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'the workspace currency'],
);

/// #1924 — what was collected: payments matched to invoices, by the month
/// of the match on the workspace clock (the money report's "matched").
const collectedKpi = KpiDefinition(
  id: 'finance.collected',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the month a payment was matched to an invoice, on the workspace '
      'clock, whole months [from, to]',
  dimensions: [],
  numerator: 'collected_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'payment matching', 'the workspace currency'],
);

/// Every KPI the app knows. One list; the server registers the same ids.
const kpiCatalogue = <KpiDefinition>[
  seatUtilisationKpi,
  invoicedKpi,
  collectedKpi,
];

/// Why a value is what it is. Several can hold at once.
enum KpiQuality {
  /// Measured, and it is zero.
  knownZero,

  /// The source does not record what the period would need.
  notRecorded,

  /// The measure has no meaning here (no offered capacity: x / 0).
  notApplicable,

  /// Some of the period could not be qualified.
  partial,

  /// Older than the caller may rely on.
  stale,

  /// The server could not answer.
  unavailable,

  /// The caller may not read it.
  forbidden,
}

KpiQuality? _quality(String wire) => switch (wire) {
  'known_zero' => KpiQuality.knownZero,
  'not_recorded' => KpiQuality.notRecorded,
  'not_applicable' => KpiQuality.notApplicable,
  'partial' => KpiQuality.partial,
  'stale' => KpiQuality.stale,
  'unavailable' => KpiQuality.unavailable,
  'forbidden' => KpiQuality.forbidden,
  _ => null,
};

/// `sum(numerator) / sum(denominator)`; null when the denominator is 0.
double? ratioOfSums(Iterable<({num numerator, num denominator})> parts) {
  num n = 0, d = 0;
  for (final p in parts) {
    if (!p.numerator.isFinite || !p.denominator.isFinite ||
        p.denominator < 0) {
      return null;
    }
    n += p.numerator;
    d += p.denominator;
  }
  return d <= 0 || !n.isFinite || !d.isFinite ? null : n / d;
}

/// What `kpi_seat_capacity` returned, typed.
class SeatCapacityKpi {
  const SeatCapacityKpi({
    required this.from,
    required this.to,
    required this.physicalSeatHours,
    required this.offeredSeatHours,
    required this.reservedSeatHours,
    required this.reservedOutsideOfferedSeatHours,
    required this.overlappingSeatHours,
    required this.seats,
    required this.roomsWithoutSeats,
    required this.offeredRoomHours,
    required this.reservedRoomHours,
    required this.quality,
    required this.reasons,
    required this.computedAt,
    this.historySince,
  });

  final DateTime from;
  final DateTime to;
  final double physicalSeatHours;
  final double offeredSeatHours;
  final double reservedSeatHours;

  /// Reserved seat time outside the offered hours (an outside-hours
  /// booking, a blocked seat). Shown, never folded into the ratio.
  final double reservedOutsideOfferedSeatHours;

  /// Seat time two active reservations claimed at once. Counted once in
  /// the numerator and named here, never clamped away silently.
  final double overlappingSeatHours;
  final int seats;

  /// Rooms with no seat at all: counted in room-hours, a separate unit
  /// that is never added to seat-hours.
  final int roomsWithoutSeats;
  final double offeredRoomHours;
  final double reservedRoomHours;
  final Set<KpiQuality> quality;

  /// Machine reasons behind [quality] (`current_structure`, …).
  final List<String> reasons;
  final DateTime computedAt;

  /// When the workspace's recorded history begins (#1920). Time before
  /// it is not counted; null from a server that predates the history.
  final DateTime? historySince;

  /// Unqualified payloads never become numbers, even with positive hours.
  bool get hasValue => !quality.any((q) =>
      q == KpiQuality.notRecorded || q == KpiQuality.notApplicable ||
      q == KpiQuality.unavailable || q == KpiQuality.forbidden);

  /// The utilisation, or null when it is undefined (nothing offered).
  double? get utilisation => !hasValue ? null : ratioOfSums([
    (numerator: reservedSeatHours, denominator: offeredSeatHours),
  ]);
}

double _num(Object? v) {
  final n = v is num ? v.toDouble() : v is String ? double.tryParse(v) : null;
  if (n == null || !n.isFinite || n < 0) {
    throw const FormatException('Invalid or missing capacity number');
  }
  return n;
}

int _count(Object? v) {
  final n = _num(v);
  if (n != n.truncateToDouble()) {
    throw const FormatException('Capacity count must be an integer');
  }
  return n.toInt();
}

/// Unknown quality is unavailable: a future suppression flag must not
/// silently turn into an apparently measured answer on an older client.
SeatCapacityKpi seatCapacityFromJson(Map<String, dynamic> json) {
  final quality = json['quality'];
  final reasons = json['reasons'];
  final from = DateTime.parse('${json['from']}');
  final to = DateTime.parse('${json['to']}');
  if (!to.isAfter(from) || quality is! List || reasons is! List) {
    throw const FormatException('Invalid capacity interval or qualification');
  }
  return SeatCapacityKpi(
    from: from,
    to: to,
    physicalSeatHours: _num(json['physical_seat_hours']),
    offeredSeatHours: _num(json['offered_seat_hours']),
    reservedSeatHours: _num(json['reserved_seat_hours']),
    reservedOutsideOfferedSeatHours: _num(
      json['reserved_outside_offered_seat_hours'],
    ),
    overlappingSeatHours: _num(json['overlapping_seat_hours']),
    seats: _count(json['seats']),
    roomsWithoutSeats: _count(json['rooms_without_seats']),
    offeredRoomHours: _num(json['offered_room_hours']),
    reservedRoomHours: _num(json['reserved_room_hours']),
    quality: {
      for (final q in quality) _quality('$q') ?? KpiQuality.unavailable,
    },
    reasons: [
      for (final r in reasons) '$r',
    ],
    computedAt: DateTime.parse('${json['computed_at']}'),
    historySince: DateTime.tryParse('${json['history_since']}'),
  );
}

/// Reads KPIs from the server. Every call is authorized there.
abstract interface class KpiRepository {
  /// `capacity.seat_utilisation` over `[from, to)`, optionally one level.
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  });
}

/// The largest magnitude JSON (an IEEE double, a JS number) carries
/// exactly: beyond it a minor-unit amount is refused, never rounded.
const int maxExactMinor = 9007199254740991;

/// What `kpi_finance_summary` returned, typed (#1924). Amounts are minor
/// units of [currency], read from decimal strings; one beyond
/// [maxExactMinor] makes the figure unavailable rather than wrong.
class FinanceSummaryKpi {
  const FinanceSummaryKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.invoicedMinor,
    required this.creditNotesMinor,
    required this.collectedMinor,
    required this.invoices,
    required this.matches,
    required this.quality,
    required this.reasons,
    required this.computedAt,
    this.lastChangeAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;

  /// Null when the amount could not travel exactly.
  final int? invoicedMinor;
  final int? creditNotesMinor;
  final int? collectedMinor;

  /// How many invoices and matches the figures are made of.
  final int invoices;
  final int matches;
  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  /// The latest change to a row behind the figures (source as-of).
  final DateTime? lastChangeAt;
}

/// An exact minor-unit amount from a decimal string (or an integer),
/// or null when it is malformed or beyond [maxExactMinor].
int? exactMinor(Object? v) {
  final big = switch (v) {
    final String s when RegExp(r'^-?[0-9]{1,30}$').hasMatch(s) => BigInt.parse(
      s,
    ),
    final int i => BigInt.from(i),
    _ => null,
  };
  if (big == null || big.abs() > BigInt.from(maxExactMinor)) return null;
  return big.toInt();
}

/// Parses the RPC's jsonb. A missing amount is NOT zero: it is null and
/// the figure is unavailable.
FinanceSummaryKpi financeSummaryFromJson(Map<String, dynamic> json) {
  final quality = json['quality'];
  final reasons = json['reasons'];
  if (quality is! List || reasons is! List) {
    throw const FormatException('Missing finance evidence');
  }
  final invoiced = exactMinor(json['invoiced_minor']);
  final credit = exactMinor(json['credit_notes_minor']);
  final collected = exactMinor(json['collected_minor']);
  final inexact = invoiced == null || credit == null || collected == null;
  final currency = json['currency'];
  return FinanceSummaryKpi(
    fromMonth: '${json['from']}',
    toMonth: '${json['to']}',
    currency: currency is String ? currency : '',
    invoicedMinor: invoiced,
    creditNotesMinor: credit,
    collectedMinor: collected,
    invoices: _count(json['invoices']),
    matches: _count(json['matches']),
    quality: {
      for (final q in quality) _quality('$q') ?? KpiQuality.unavailable,
      if (inexact || currency is! String || currency.isEmpty)
        KpiQuality.unavailable,
    },
    reasons: [
      for (final r in reasons) '$r',
      if (inexact) 'amount_not_exact',
    ],
    computedAt: DateTime.parse('${json['computed_at']}'),
    lastChangeAt: DateTime.tryParse('${json['last_change_at']}'),
  );
}

/// Reads the finance KPIs (#1924). Every call is authorized there.
abstract interface class FinanceKpiRepository {
  /// Invoiced and collected over the whole months [fromMonth, toMonth]
  /// (`YYYY-MM`).
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}

/// The demonstration has no server to sum invoices on.
class UnavailableFinanceKpiRepository implements FinanceKpiRepository {
  const UnavailableFinanceKpiRepository();

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #2327 — how a KPI read retries. A refusal or an unavailable source is
/// an ANSWER, not a hiccup: retrying it kept the demonstration's finance
/// cards loading for a minute. Anything else retries briefly.
Duration? kpiRetry(int count, Object error) {
  if (error is KpiForbidden || error is KpiUnavailable) return null;
  if (count >= 3) return null;
  return Duration(milliseconds: 200 << count);
}

/// The server refused: the reader may not see this KPI here.
class KpiForbidden implements Exception {
  const KpiForbidden();
}

/// The KPI could not be computed (no backend, the demonstration, an
/// error). Never a zero in disguise.
class KpiUnavailable implements Exception {
  const KpiUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'KpiUnavailable: $reason';
}

/// The demonstration has no server to compute capacity on: the tile
/// says so rather than inventing a figure.
class UnavailableKpiRepository implements KpiRepository {
  const UnavailableKpiRepository();

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #1921 — the server's copy of the catalogue: per KPI its version, what
/// it discloses and the permissions it needs. `kpi_registry()` in the
/// latest migration must hold exactly this (kpi_registry_sql_test).
String kpiRegistryJson() => jsonEncode({
  for (final k in kpiCatalogue)
    k.id: {
      'version': k.version,
      'disclosure': k.disclosure.wire,
      'permissions': k.permissions,
      if (k.minCohort != null) 'min_cohort': k.minCohort,
    },
});
