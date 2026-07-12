// SPDX-License-Identifier: MIT

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
  halfDay('half_day');
  // Append only (AGENT_RULES: wire values are persisted, never reorder).

  const BookingGranularity(this.wireName);

  /// Stable jsonb value inside `booking_rules` (snake_case).
  final String wireName;

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

/// Server-side error text raised by `enforce_booking_rules`
/// (migration 0025) when a booking violates the half-day granularity:
/// `bookings must cover a half-day (00:00-13:00, 13:00-24:00) or the
/// full day`. The booking error mapping matches this substring (#201).
/// Pinned by test against the migration file.
abstract final class BookingGranularityError {
  static const String serverSubstring = 'half-day';
}
