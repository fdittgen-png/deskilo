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

/// How a KPI may be combined across a dimension or across time.
enum KpiAggregation {
  /// sum(numerator) / sum(denominator) over the whole scope.
  ratioOfSums,

  /// Additive over disjoint intervals and resources.
  sum,
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
    required this.permission,
    required this.prerequisites,
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

  /// The `WorkspacePermission` wire name the server checks.
  final String permission;
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
  permission: 'manageReservations',
  prerequisites: [
    'opening weekdays and hours (booking rules)',
    'closure days',
    'seat blocks',
  ],
);

/// Every KPI the app knows. One list; the server registers the same ids.
const kpiCatalogue = <KpiDefinition>[seatUtilisationKpi];

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
    n += p.numerator;
    d += p.denominator;
  }
  return d == 0 ? null : n / d;
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

  /// The utilisation, or null when it is undefined (nothing offered).
  double? get utilisation => ratioOfSums([
    (numerator: reservedSeatHours, denominator: offeredSeatHours),
  ]);
}

double _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

/// Parses the RPC's jsonb. Unknown quality words are ignored, so an
/// older client survives a newer server.
SeatCapacityKpi seatCapacityFromJson(Map<String, dynamic> json) {
  final quality = json['quality'];
  final reasons = json['reasons'];
  return SeatCapacityKpi(
    from: DateTime.parse('${json['from']}'),
    to: DateTime.parse('${json['to']}'),
    physicalSeatHours: _num(json['physical_seat_hours']),
    offeredSeatHours: _num(json['offered_seat_hours']),
    reservedSeatHours: _num(json['reserved_seat_hours']),
    reservedOutsideOfferedSeatHours: _num(
      json['reserved_outside_offered_seat_hours'],
    ),
    overlappingSeatHours: _num(json['overlapping_seat_hours']),
    seats: _num(json['seats']).toInt(),
    roomsWithoutSeats: _num(json['rooms_without_seats']).toInt(),
    offeredRoomHours: _num(json['offered_room_hours']),
    reservedRoomHours: _num(json['reserved_room_hours']),
    quality: {
      if (quality is List)
        for (final q in quality)
          if (_quality('$q') case final KpiQuality k) k,
    },
    reasons: [
      if (reasons is List)
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
