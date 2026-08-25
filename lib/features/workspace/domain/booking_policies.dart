// SPDX-License-Identifier: 0BSD

/// #624 — how bookings whose window lies ENTIRELY outside the working
/// hours are treated (`booking_rules.outside_hours_mode`). Absent or
/// unknown wire values read as [charged], the closest to the historical
/// behavior. The server enforces it in migration 0118
/// (`enforce_booking_rules` v7, `assert_member_quota` v4,
/// `member_statement` v11 — one shared predicate).
enum OutsideHoursMode {
  /// Outside-only bookings and walk-up check-ins are refused.
  off('off'),

  /// Allowed but never counted or charged — pure presence info.
  free('free'),

  /// Counted like regular usage, except next to a regular
  /// (inside-hours) reservation on the same workspace-local day —
  /// then the outside-only booking rides free.
  charged('charged');

  const OutsideHoursMode(this.wire);

  /// The `booking_rules` string value.
  final String wire;

  /// Absent/unknown → [charged] (the server does the same).
  static OutsideHoursMode fromWire(Object? value) =>
      values.firstWhere((m) => m.wire == value, orElse: () => charged);
}

/// Owner-configurable booking-behavior matrix (#600) — three policy
/// switches stored as `booking_rules` keys, every one defaulting OFF
/// (the historical behavior). The server enforces them in migration
/// 0116 (`create_reservation` v10, `enforce_booking_rules` v6,
/// `check_out_reservation` v2); this class is the client mirror.
/// #624 adds the outside-hours mode (see [OutsideHoursMode]).
class BookingPolicies {
  const BookingPolicies({
    this.allowPastBookings = false,
    this.gridWithinHours = false,
    this.adminCheckOut = false,
    this.outsideHoursMode = OutsideHoursMode.charged,
  });

  /// `allow_past_bookings` — ON lets a member record a booking that
  /// already ended (deliberate backfill); OFF refuses it.
  final bool allowPastBookings;

  /// `grid_within_hours` — ON confines minute-grid bookings to the
  /// working day (overtime walk-ups excepted); OFF keeps grids
  /// free-time (the 0032 behavior).
  final bool gridWithinHours;

  /// `admin_check_out` — ON lets an admin end a member's running
  /// check-in; OFF keeps check-out owner-only.
  final bool adminCheckOut;

  /// `outside_hours_mode` (#624) — the outside-only booking policy.
  final OutsideHoursMode outsideHoursMode;

  static const allowPastBookingsKey = 'allow_past_bookings';
  static const gridWithinHoursKey = 'grid_within_hours';
  static const adminCheckOutKey = 'admin_check_out';
  static const outsideHoursModeKey = 'outside_hours_mode';

  /// Reads the three keys from a `booking_rules` map; the server treats
  /// only jsonb `true` (rendered `'true'` by `->>`) as ON, so both the
  /// boolean and its string form count.
  factory BookingPolicies.fromRules(Map<String, dynamic>? rules) {
    bool on(String key) {
      final v = rules?[key];
      return v == true || v == 'true';
    }

    return BookingPolicies(
      allowPastBookings: on(allowPastBookingsKey),
      gridWithinHours: on(gridWithinHoursKey),
      adminCheckOut: on(adminCheckOutKey),
      outsideHoursMode:
          OutsideHoursMode.fromWire(rules?[outsideHoursModeKey]),
    );
  }

  BookingPolicies copyWith({
    bool? allowPastBookings,
    bool? gridWithinHours,
    bool? adminCheckOut,
    OutsideHoursMode? outsideHoursMode,
  }) =>
      BookingPolicies(
        allowPastBookings: allowPastBookings ?? this.allowPastBookings,
        gridWithinHours: gridWithinHours ?? this.gridWithinHours,
        adminCheckOut: adminCheckOut ?? this.adminCheckOut,
        outsideHoursMode: outsideHoursMode ?? this.outsideHoursMode,
      );
}
