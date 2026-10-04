// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a figure is made of, as parts of a whole that add up — from the
// numbers the data already carries, never from a guess.
//
//   * Seat time: of all the physical seat-hours of the period, how much was
//     reserved inside the opening hours, how much was free inside them, and
//     how much lay outside them (closed). The three add up to the physical
//     hours, so the reader sees what share of the building's time the
//     figure is a share of.
//   * Collection: of what was invoiced, how much was collected and how much
//     is still to collect. Only when the collected amount does not exceed
//     the invoiced one (payments of earlier invoices would break the part-
//     of-whole reading); otherwise there is no composition and the caller
//     says so.
//
// A part that would be negative, or a whole that is not positive, yields
// null: no composition is shown rather than a misleading one.
//
// Pure Dart.
library;

import 'bi_analysis.dart';
import 'kpi_contract.dart';

/// The words of the parts, supplied by the caller (localised there).
class SeatTimeLabels {
  const SeatTimeLabels({
    required this.reserved,
    required this.free,
    required this.closed,
  });

  final String reserved;
  final String free;
  final String closed;
}

/// The physical seat-hours of [k] as reserved / free / closed parts.
List<BiShare>? seatTimeComposition(SeatCapacityKpi k, SeatTimeLabels labels) {
  if (!k.hasValue) return null;
  final physical = k.physicalSeatHours;
  final offered = k.offeredSeatHours;
  final reservedWithin = k.reservedSeatHours - k.reservedOutsideOfferedSeatHours;
  final free = offered - reservedWithin;
  final closed = physical - offered;
  if (!physical.isFinite || physical <= 0) return null;
  if (reservedWithin < -0.005 || free < -0.005 || closed < -0.005) return null;
  double part(double v) => v < 0 ? 0 : v;
  final parts = [
    ('reserved', labels.reserved, part(reservedWithin)),
    ('free', labels.free, part(free)),
    ('closed', labels.closed, part(closed)),
  ];
  final whole = parts.fold<double>(0, (a, p) => a + p.$3);
  if (whole <= 0) return null;
  return [
    for (final (key, label, value) in parts)
      if (value > 0)
        BiShare(key: key, label: label, value: value, share: value / whole),
  ];
}

/// Collected and still-to-collect parts of [invoiced], in minor units.
List<BiShare>? collectionComposition({
  required int? invoiced,
  required int? collected,
  required String collectedLabel,
  required String outstandingLabel,
}) {
  if (invoiced == null || collected == null) return null;
  if (invoiced <= 0 || collected < 0 || collected > invoiced) return null;
  final outstanding = invoiced - collected;
  return [
    if (collected > 0)
      BiShare(
        key: 'collected',
        label: collectedLabel,
        value: collected,
        share: collected / invoiced,
      ),
    if (outstanding > 0)
      BiShare(
        key: 'outstanding',
        label: outstandingLabel,
        value: outstanding,
        share: outstanding / invoiced,
      ),
  ];
}
