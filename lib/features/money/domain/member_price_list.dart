// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a member pays at each level the space offers (ADR 0008): the
// monthly fee of the band the level falls into, and what a half-day and
// a whole day booked beyond the level's entitlement cost. The band is
// found the way the financial agreement finds it ([feeBandFor]), so the
// setup preview and the letter a member receives never disagree.
import 'fee_band.dart';

/// A day is two half-days and never more (ADR 0006, ADR 0008): the
/// booking grain every entitlement and every extra is counted in.
const int _halfDaysPerDay = 2;

/// One offered level and the band that prices it.
class LevelPrice {
  const LevelPrice({required this.pct, required this.band});

  /// The subscription percentage, 1–100.
  final int pct;

  /// Null when no band covers [pct]: the level has no price yet.
  final FeeBand? band;

  int? get monthlyCents => band?.feeCents;

  /// A half-day booked beyond the entitlement.
  int? get extraHalfDayCents => band?.overageFeeCents;

  /// A whole day beyond the entitlement: two extra half-days.
  int? get extraDayCents {
    final half = extraHalfDayCents;
    return half == null ? null : half * _halfDaysPerDay;
  }
}

/// [levels] in ascending order, each with the band that prices it.
List<LevelPrice> memberPriceList(List<FeeBand> bands, Iterable<int> levels) {
  final sorted = {...levels}.toList()..sort();
  return [
    for (final pct in sorted)
      LevelPrice(pct: pct, band: feeBandFor(bands, pct)),
  ];
}

/// #3283 (ADR 0008) — the half-days a level includes in a month the
/// workspace is open [openDays] days: `ceil(openDays × 2 × pct / 100)`.
int includedHalfDays(int openDays, int pct) =>
    (openDays * _halfDaysPerDay * pct + 99) ~/ 100;

/// The days of [month] the workspace is open: its [openWeekdays] (ISO,
/// Monday = 1) less the [closures] that fall in that month.
int openDaysIn(
  DateTime month,
  Iterable<int> openWeekdays,
  Iterable<DateTime> closures,
) {
  final weekdays = openWeekdays.toSet();
  final closed = {
    for (final c in closures)
      if (c.year == month.year && c.month == month.month) c.day,
  };
  final last = DateTime(month.year, month.month + 1, 0).day;
  var open = 0;
  for (var day = 1; day <= last; day++) {
    final date = DateTime(month.year, month.month, day);
    if (weekdays.contains(date.weekday) && !closed.contains(day)) open++;
  }
  return open;
}
