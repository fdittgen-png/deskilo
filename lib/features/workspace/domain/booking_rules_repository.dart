// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/work_hours.dart';
import 'booking_granularity.dart';
import 'booking_policies.dart';
import 'closure_day.dart';
import 'public_holidays.dart';
import 'work_hours_provenance.dart';

/// When and how a space can be booked: open days, granularity, work hours, policies, limits, closure days, default period.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class BookingRulesRepository {
  /// ISO weekdays (1=Mon..7=Sun) the workspace is open on (#127); read
  /// from booking_rules, defaults to Mon–Fri when the key is absent.
  Future<List<int>> fetchOpenWeekdays(String workspaceId);

  /// Owner-only (RLS-enforced): persist the open weekdays inside
  /// booking_rules without clobbering its other keys.
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays);

  /// The workspace's booking-granularity rule (#200); read from
  /// booking_rules, [BookingGranularity.flexible] when absent.
  Future<BookingGranularity> fetchBookingGranularity(String workspaceId);

  /// Owner-only (RLS-enforced): persist the granularity inside
  /// booking_rules without clobbering its other keys.
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  );

  /// The workspace's working day (#446); read from booking_rules,
  /// [WorkHours.defaults] when the keys are absent or inconsistent.
  Future<WorkHours> fetchWorkHours(String workspaceId);

  /// Owner-only (RLS-enforced): persist the working day inside
  /// booking_rules without clobbering its other keys.
  Future<void> setWorkHours(String workspaceId, WorkHours hours);

  /// #1307 S4 — where the working day came from, and the way back to the
  /// product's own hours (the keys removed).
  Future<WorkHoursProvenance> fetchWorkHoursProvenance(String workspaceId);

  Future<void> resetWorkHoursToDefault(String workspaceId);

  /// The three #600 booking-policy switches (booking_rules keys).
  Future<BookingPolicies> fetchBookingPolicies(String workspaceId);

  /// Writes one #600 policy key, preserving the other booking_rules.
  Future<void> setBookingPolicy(
    String workspaceId,
    String key, {
    required bool enabled,
  });

  /// Writes the #624 outside-hours mode (`outside_hours_mode` string
  /// key), preserving the other booking_rules.
  /// #1281 — `legend_profile`: how many states the plan tells apart.
  /// Owner-only, like every other booking rule.
  Future<void> setLegendProfile(String workspaceId, LegendProfile profile);

  Future<void> setOutsideHoursMode(String workspaceId, OutsideHoursMode mode);

  /// Writes the #628 workspace default for simultaneous reservations
  /// (`simultaneous_reservations`, an int key), preserving the other
  /// booking_rules. 1 = the historical one-place-at-a-time.
  Future<void> setSimultaneousReservations(String workspaceId, int value);

  /// #649 — writes one of the three numeric booking limits the server has
  /// always enforced but nothing could set: `advance_horizon_days`,
  /// `min_duration_minutes`, `max_duration_minutes`. Same
  /// merge-preserving booking_rules write as the other policies.
  Future<void> setBookingLimit(String workspaceId, String key, int value);

  /// One-off closure days of the workspace, ordered by day (#127).
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId);

  /// Owner-only: add a closure day. Returns the created row.
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  );

  /// Owner-only: remove a closure day.
  Future<void> removeClosureDay(String closureDayId);

  /// #1274 — the public holidays of [year] in [country], previewed when
  /// [apply] is false and written when it is true. One server call for
  /// both, so the list an owner confirms is the list that gets written.
  Future<HolidayGeneration> generateClosureDays(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  });

  /// #2051 — the owner's chosen [days] (date + name, from the open-data
  /// source), previewed when [apply] is false and written when it is
  /// true. Same server rules as [generateClosureDays].
  Future<HolidayGeneration> importClosureDays(
    String workspaceId, {
    required List<({DateTime day, String name})> days,
    bool apply = false,
  });

  /// #1294 — the workspace's fallback default booking period
  /// (`booking_rules.default_period`), used only when the device holds
  /// no choice of its own. Null when unset or blank.
  Future<String?> fetchDefaultPeriod(String workspaceId);

  /// Writes it, preserving every other booking rule. '' clears it.
  Future<void> setDefaultPeriod(String workspaceId, String? wire);
}
