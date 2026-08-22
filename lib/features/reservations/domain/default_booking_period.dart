// SPDX-License-Identifier: 0BSD
//
// #586 — the member's DEFAULT reservation period. The offered choices
// derive from the workspace's booking configuration: day-based and
// hours workspaces offer the canonical windows, a full-day workspace
// has nothing to choose (every booking IS the full day), and minute
// grids pick freely so no day-window preference applies.
import '../../plan/domain/half_day_windows.dart';
import '../../workspace/domain/booking_granularity.dart';

enum DefaultBookingPeriod {
  morning('morning'),
  afternoon('afternoon'),
  fullDay('full_day');

  const DefaultBookingPeriod(this.wire);

  /// Stable id in the persisted preference — survives enum renames.
  final String wire;

  static DefaultBookingPeriod? fromWire(String? value) {
    for (final period in values) {
      if (period.wire == value) return period;
    }
    return null;
  }
}

/// Which default-period choices the workspace configuration supports.
/// Empty = the preference does not apply (nothing to pre-select).
List<DefaultBookingPeriod> defaultPeriodChoicesFor(
  BookingGranularity granularity,
) {
  if (granularity == BookingGranularity.fullDay) return const [];
  if (granularity.offersDayWindows) return DefaultBookingPeriod.values;
  return const [];
}

/// The canonical window [period] means on [day]; a member with no
/// preference keeps the historical full-day default.
HalfDayWindow defaultWindowFor(
  DefaultBookingPeriod? period,
  DateTime day,
) =>
    switch (period) {
      DefaultBookingPeriod.morning => HalfDayWindows.morning(day),
      DefaultBookingPeriod.afternoon => HalfDayWindows.afternoon(day),
      DefaultBookingPeriod.fullDay || null => HalfDayWindows.fullDay(day),
    };
