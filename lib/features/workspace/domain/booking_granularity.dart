// SPDX-License-Identifier: 0BSD

/// Workspace booking-granularity rule (#200) — stored inside the
/// `booking_rules` jsonb under [BookingRulesKeys.granularity] and
/// enforced server-side by `enforce_booking_rules` (migration 0025).
///
/// Under [halfDay] a booking must cover exactly one of the canonical
/// workspace-local windows — 00:00–13:00 (morning), 13:00–24:00
/// (afternoon) or 00:00–24:00 (full day) — matching the billing halves
/// (13:00 pivot, spec §7). An absent or unknown value means [flexible].
enum BookingGranularity {
  flexible('flexible'),
  halfDay('half_day'),
  minutes5('minutes_5'),
  minutes15('minutes_15'),
  minutes30('minutes_30'),
  minutes60('minutes_60'),
  fullDay('full_day'),

  /// Real hours (#446): the user books exact from→to times AND may
  /// still pick the canonical half/full-day windows — the reserve UI
  /// offers both. The server enforces no grid for it; the statement
  /// bills booked time as half-day equivalents via
  /// `WorkHours.halfDayHours`.
  hours('hours');
  // Append only (AGENT_RULES: wire values are persisted, never reorder).

  const BookingGranularity(this.wireName);

  /// Stable jsonb value inside `booking_rules` (snake_case).
  final String wireName;

  /// The time-picker snap step for minute granularities. Legacy
  /// [flexible] keeps the historical 15-minute UI snap (#184) — the
  /// server enforces nothing for it. Null for the day-based modes.
  int? get stepMinutes => switch (this) {
        minutes5 => 5,
        flexible || minutes15 || hours => 15,
        minutes30 => 30,
        minutes60 => 60,
        halfDay || fullDay => null,
      };

  /// Floors [minutesOfDay] onto this granularity's grid — the ONE
  /// snapping rule every booking surface shares (#638: the booking sheet,
  /// the window edit and the extend/shrink flows each carried their own
  /// copy, and they had already drifted between flooring and rounding).
  /// Day-based modes have no grid; they keep the legacy 15-minute UI snap
  /// so a caller that reaches here with one still lands on a sane time.
  int snapMinutesOfDay(int minutesOfDay) {
    final step = stepMinutes ?? 15;
    return (minutesOfDay ~/ step) * step;
  }

  /// Whole-window modes: bookings cover canonical day windows (morning /
  /// afternoon / full day for [halfDay]; the full day only for
  /// [fullDay]) instead of free from→to times.
  bool get isDayBased => this == halfDay || this == fullDay;

  /// Whether the reserve UI offers the half/full-day window chips: the
  /// day-based modes (only those) and [hours], which offers the chips
  /// NEXT TO free from→to times (#446).
  bool get offersDayWindows => isDayBased || this == hours;

  /// The granularity for [wireName]; null / unknown values fall back to
  /// [flexible] (forward compatibility: rules written by a newer app
  /// version must not crash an older client).
  static BookingGranularity fromWire(String? wireName) {
    for (final granularity in values) {
      if (granularity.wireName == wireName) return granularity;
    }
    return flexible;
  }
}

/// Keys inside the `booking_rules` jsonb touched by the client. Pinned
/// by test — renaming is a data-compatibility decision.
abstract final class BookingRulesKeys {
  static const String granularity = 'granularity';
}

/// Server-side error texts raised by `enforce_booking_rules` when a
/// booking violates the granularity — half-day windows (0025/0026), the
/// minute grid or the full-day window (0032). The booking error mapping
/// matches these substrings; pinned by test against the migration files.
abstract final class BookingGranularityError {
  static const String serverSubstring = 'half-day';
  static const String slotServerSubstring = 'minute grid';
  static const String fullDayServerSubstring = 'cover the full day';
}
