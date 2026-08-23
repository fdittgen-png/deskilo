// SPDX-License-Identifier: 0BSD

/// Owner-configurable booking-behavior matrix (#600) — three policy
/// switches stored as `booking_rules` keys, every one defaulting OFF
/// (the historical behavior). The server enforces them in migration
/// 0116 (`create_reservation` v10, `enforce_booking_rules` v6,
/// `check_out_reservation` v2); this class is the client mirror.
class BookingPolicies {
  const BookingPolicies({
    this.allowPastBookings = false,
    this.gridWithinHours = false,
    this.adminCheckOut = false,
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

  static const allowPastBookingsKey = 'allow_past_bookings';
  static const gridWithinHoursKey = 'grid_within_hours';
  static const adminCheckOutKey = 'admin_check_out';

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
    );
  }

  BookingPolicies copyWith({
    bool? allowPastBookings,
    bool? gridWithinHours,
    bool? adminCheckOut,
  }) =>
      BookingPolicies(
        allowPastBookings: allowPastBookings ?? this.allowPastBookings,
        gridWithinHours: gridWithinHours ?? this.gridWithinHours,
        adminCheckOut: adminCheckOut ?? this.adminCheckOut,
      );
}
