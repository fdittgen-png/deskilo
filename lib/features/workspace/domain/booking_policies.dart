// SPDX-License-Identifier: 0BSD

/// #634 — THE one answer to "what may happen outside the configured
/// working day?" (`booking_rules.outside_hours_mode`). Four mutually
/// exclusive values; absent or unknown wire values read as [charged],
/// the closest to the historical behavior. #624 shipped the first three
/// for windows lying ENTIRELY outside the hours; #634 added
/// [walkupOnly] and widened ENFORCEMENT to windows that merely SPILL
/// out of the day, folding in the retired `grid_within_hours` switch
/// (#600). The server enforces it in migration 0120
/// (`enforce_booking_rules` v8); BILLING scope is unchanged — the
/// free/exempt treatment in `reservation_counts_for_usage` (0118,
/// feeding `assert_member_quota` and `member_statement`) still keys on
/// entirely-outside windows only.
enum OutsideHoursMode {
  /// Nothing outside the working day: no booking ahead, no walk-up —
  /// and a window spilling past the day end (or starting before the day
  /// start) is refused too.
  off('off'),

  /// Allowed but never counted or charged — pure presence info.
  free('free'),

  /// Counted like regular usage, except next to a regular
  /// (inside-hours) reservation on the same workspace-local day —
  /// then the outside-only booking rides free.
  charged('charged'),

  /// Spontaneous only: a walk-up check-in outside the hours stays
  /// possible (evening overtime to local midnight included), while
  /// RESERVING AHEAD outside the hours — and any spilling window — is
  /// refused. Exactly what `grid_within_hours` did, on every
  /// granularity. Appended last: enum values are append-only here.
  walkupOnly('walkup_only');

  const OutsideHoursMode(this.wire);

  /// The `booking_rules` string value.
  final String wire;

  /// Absent/unknown → [charged] (the server does the same).
  static OutsideHoursMode fromWire(Object? value) =>
      resolve(value, gridWithinHours: false);

  /// The mirror of the server's single resolution (migration 0120):
  ///
  ///     coalesce(outside_hours_mode,
  ///              case when grid_within_hours = 'true'
  ///                   then 'walkup_only' else 'charged' end)
  ///
  /// An explicit mode always wins; the legacy #600 key is only ever
  /// READ, never written again. A PRESENT but unknown value is not
  /// absent — like the server's `coalesce`, it short-circuits the
  /// fallback and lands on [charged].
  static OutsideHoursMode resolve(
    Object? value, {
    required bool gridWithinHours,
  }) {
    if (value == null) return gridWithinHours ? walkupOnly : charged;
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    return charged;
  }
}

/// Owner-configurable booking-behavior matrix (#600) — policy switches
/// stored as `booking_rules` keys, every bool defaulting OFF (the
/// historical behavior). The server enforces them in migration 0116
/// (`create_reservation` v10, `enforce_booking_rules` v6,
/// `check_out_reservation` v2); this class is the client mirror.
/// #624 added the outside-hours mode (see [OutsideHoursMode]), #628 the
/// simultaneous-reservations allowance (migration 0119) and #634 folded
/// #600's `grid_within_hours` switch INTO the outside-hours mode
/// (migration 0120) — that key is now read-only legacy.
class BookingPolicies {
  const BookingPolicies({
    this.allowPastBookings = false,
    this.adminCheckOut = false,
    this.outsideHoursMode = OutsideHoursMode.charged,
    this.simultaneousReservations = defaultSimultaneous,
    this.advanceHorizonDays = defaultHorizonDays,
    this.minDurationMinutes = defaultMinDuration,
    this.maxDurationMinutes = defaultMaxDuration,
  });

  /// `allow_past_bookings` — ON lets a member record a booking that
  /// already ended (deliberate backfill); OFF refuses it.
  final bool allowPastBookings;

  /// `admin_check_out` — ON lets an admin end a member's running
  /// check-in; OFF keeps check-out owner-only.
  final bool adminCheckOut;

  /// `outside_hours_mode` (#624, four-valued since #634) — THE
  /// outside-the-working-day policy.
  final OutsideHoursMode outsideHoursMode;

  /// `simultaneous_reservations` (#628) — how many overlapping active
  /// bookings one member may hold. 1 is the historical "one place at a
  /// time" (#412); a per-member permission may raise it further.
  final int simultaneousReservations;

  /// `advance_horizon_days` (#649) — how far ahead a booking may be made.
  /// The server has enforced this since migration 0006 and defaulted it
  /// to 90; it simply had no control until now.
  final int advanceHorizonDays;

  /// `min_duration_minutes` (#649) — the shortest booking accepted, on
  /// EVERY granularity. It is why an 11:45 walk-up for the 12:00
  /// half-day boundary is refused as too short.
  final int minDurationMinutes;

  /// `max_duration_minutes` (#649) — the longest booking accepted. Since
  /// #644 a booking ends on the day it starts, so a full day is the
  /// natural ceiling and [maxDurationCeiling] is exactly that.
  final int maxDurationMinutes;

  static const allowPastBookingsKey = 'allow_past_bookings';
  static const adminCheckOutKey = 'admin_check_out';

  /// #600's retired switch (#634). READ-ONLY legacy: it no longer has a
  /// field or a UI control — a stored `true` resolves to
  /// [OutsideHoursMode.walkupOnly], and nothing writes the key again.
  static const gridWithinHoursKey = 'grid_within_hours';
  static const outsideHoursModeKey = 'outside_hours_mode';
  static const simultaneousReservationsKey = 'simultaneous_reservations';

  /// Absent/invalid reads as one place at a time — exactly what the
  /// server's `member_simultaneous_allowance` falls back to.
  static const defaultSimultaneous = 1;

  /// The sanity ceiling the server pins in its 1..20 check constraint.
  static const maxSimultaneous = 20;

  static const advanceHorizonDaysKey = 'advance_horizon_days';
  static const minDurationMinutesKey = 'min_duration_minutes';
  static const maxDurationMinutesKey = 'max_duration_minutes';

  /// #649 — the three defaults `enforce_booking_rules` coalesces to when
  /// the key is absent (migration 0122, lines 110–112). The client MUST
  /// agree with them: an untouched workspace has no key at all, so what
  /// the screen shows is a mirror of the server's fallback, not a value
  /// anyone stored.
  static const defaultHorizonDays = 90;
  static const defaultMinDuration = 30;
  static const defaultMaxDuration = 1440;

  /// Bounds. The horizon spans a day to two years. Durations are minutes
  /// of ONE day: since #644 a booking ends on the day it starts, so
  /// nothing above a full day can ever be accepted, whatever is stored.
  static const minHorizonDays = 1;
  static const maxHorizonDays = 730;
  static const durationFloor = 5;
  static const maxDurationCeiling = 1440;

  /// Reads the policy keys from a `booking_rules` map; the server treats
  /// only jsonb `true` (rendered `'true'` by `->>`) as ON, so both the
  /// boolean and its string form count.
  factory BookingPolicies.fromRules(Map<String, dynamic>? rules) {
    bool on(String key) {
      final v = rules?[key];
      return v == true || v == 'true';
    }

    return BookingPolicies(
      allowPastBookings: on(allowPastBookingsKey),
      adminCheckOut: on(adminCheckOutKey),
      // #634: ONE resolution, mirroring migration 0120's gate — the
      // explicit mode wins, else the legacy #600 key maps.
      outsideHoursMode: OutsideHoursMode.resolve(
        rules?[outsideHoursModeKey],
        gridWithinHours: on(gridWithinHoursKey),
      ),
      simultaneousReservations:
          simultaneousFromWire(rules?[simultaneousReservationsKey]),
      advanceHorizonDays: intFromWire(
        rules?[advanceHorizonDaysKey],
        fallback: defaultHorizonDays,
        min: minHorizonDays,
        max: maxHorizonDays,
      ),
      minDurationMinutes: intFromWire(
        rules?[minDurationMinutesKey],
        fallback: defaultMinDuration,
        min: durationFloor,
        max: maxDurationCeiling,
      ),
      maxDurationMinutes: intFromWire(
        rules?[maxDurationMinutesKey],
        fallback: defaultMaxDuration,
        min: durationFloor,
        max: maxDurationCeiling,
      ),
    );
  }

  /// #649 — a jsonb number or its string form, clamped into [min]..[max];
  /// anything unreadable (absent, text, null) falls back. Same shape as
  /// [simultaneousFromWire], which predates it and keeps its own name
  /// because the server has a matching check constraint only for that
  /// one.
  static int intFromWire(
    Object? value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final n = switch (value) {
      final int v => v,
      final num v => v.floor(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (n == null) return fallback;
    return n.clamp(min, max);
  }

  /// True when the durations contradict each other. The server compares
  /// each bound independently, so a minimum above the maximum refuses
  /// EVERY booking — the screen must not let an owner save that.
  bool get durationsAreCoherent => minDurationMinutes <= maxDurationMinutes;

  /// #628 — a jsonb number or its string form; anything else (absent,
  /// text, zero, negative) falls back to [defaultSimultaneous], and
  /// anything above [maxSimultaneous] is clamped, like the server.
  static int simultaneousFromWire(Object? value) {
    final n = switch (value) {
      final int v => v,
      final num v => v.floor(),
      final String v => int.tryParse(v.trim()) ?? defaultSimultaneous,
      _ => defaultSimultaneous,
    };
    if (n < defaultSimultaneous) return defaultSimultaneous;
    return n > maxSimultaneous ? maxSimultaneous : n;
  }

  /// Mirror of the server's `member_simultaneous_allowance` (#628,
  /// migration 0119): the member's explicit permission wins, else the
  /// workspace default, else one place at a time. [memberOverride] is
  /// `members.max_simultaneous_reservations` — null means "follow the
  /// workspace".
  static int allowanceFor(int? memberOverride, BookingPolicies policies) =>
      memberOverride == null
          ? policies.simultaneousReservations
          : simultaneousFromWire(memberOverride);

  BookingPolicies copyWith({
    bool? allowPastBookings,
    bool? adminCheckOut,
    OutsideHoursMode? outsideHoursMode,
    int? simultaneousReservations,
    int? advanceHorizonDays,
    int? minDurationMinutes,
    int? maxDurationMinutes,
  }) =>
      BookingPolicies(
        allowPastBookings: allowPastBookings ?? this.allowPastBookings,
        adminCheckOut: adminCheckOut ?? this.adminCheckOut,
        outsideHoursMode: outsideHoursMode ?? this.outsideHoursMode,
        simultaneousReservations:
            simultaneousReservations ?? this.simultaneousReservations,
        advanceHorizonDays: advanceHorizonDays ?? this.advanceHorizonDays,
        minDurationMinutes: minDurationMinutes ?? this.minDurationMinutes,
        maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      );
}
