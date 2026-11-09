// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 W2 -- the booking-rule half of the in-memory workspace repository: the
// open weekdays, granularity, work hours, policies, limits, closure days and
// the default period, by the server's rules. A mixin composed into
// `FakeWorkspaceRepository`; its state fields keep their names, so no test
// changes.
import 'dart:async';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/booking_rules_repository.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/domain/public_holidays.dart';
import 'package:deskilo/features/workspace/domain/work_hours_provenance.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

mixin FakeBookingRules implements BookingRulesRepository {
  /// The host's id counter (`FakeWorkspaceRepository`).
  int get nextId;
  set nextId(int value);

  final holidayImportCalls =
      <({List<({DateTime day, String name})> days, bool apply})>[];

  /// ISO open weekdays (1=Mon..7=Sun) per workspace; Mon–Fri when unseeded.
  final Map<String, List<int>> openWeekdays = {};

  /// Booking granularity per workspace (#200); flexible when unseeded —
  /// stored beside [openWeekdays] like the separate booking_rules keys.
  final Map<String, BookingGranularity> bookingGranularities = {};

  /// The #600 policy switches per workspace; all OFF when unseeded.
  final Map<String, BookingPolicies> bookingPolicies = {};

  /// #1294 — the workspace's fallback default period, by workspace.
  final Map<String, String?> workspaceDefaultPeriods = {};

  /// Working day per workspace (#446); defaults like the real repo.
  final Map<String, WorkHours> workHours = {};

  /// #1307 S4 — provenance per workspace; unset reads as the product default.
  final workHoursProvenance = <String, WorkHoursProvenance>{};

  final workHoursResets = <String>[];

  /// One-off closure days across workspaces (#127).
  final List<ClosureDay> closureDays = [];

  /// #1274 — what `generate_closure_days` hands back. Tests seed this;
  /// the fake never recomputes the calendar.
  HolidayGeneration holidayGeneration = HolidayGeneration.empty;

  /// Every generate call, in order, so a test can prove a preview did
  /// not write and an apply did.
  final holidayCalls =
      <({String country, int year, bool apply})>[];

  /// #2051 — months the fake treats as invoiced (`2026-07`), and every
  /// import call in order, so a test can prove which days were sent.
  final Set<String> invoicedMonths = {};

  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async =>
      List.of(openWeekdays[workspaceId] ?? const [1, 2, 3, 4, 5]);

  @override
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) async {
    openWeekdays[workspaceId] = List.of(weekdays);
  }

  @override
  Future<BookingGranularity> fetchBookingGranularity(
    String workspaceId,
  ) async =>
      bookingGranularities[workspaceId] ?? BookingGranularity.flexible;

  @override
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  ) async {
    bookingGranularities[workspaceId] = granularity;
  }

  @override
  Future<WorkHours> fetchWorkHours(String workspaceId) async =>
      workHours[workspaceId] ?? WorkHours.defaults;

  @override
  Future<void> setWorkHours(String workspaceId, WorkHours hours) async {
    workHours[workspaceId] = hours;
  }

  @override
  Future<WorkHoursProvenance> fetchWorkHoursProvenance(String workspaceId) async =>
      workHoursProvenance[workspaceId] ?? WorkHoursProvenance.productDefault;

  @override
  Future<void> resetWorkHoursToDefault(String workspaceId) async {
    workHoursResets.add(workspaceId);
    workHours.remove(workspaceId);
    workHoursProvenance[workspaceId] = WorkHoursProvenance.productDefault;
  }

  @override
  Future<BookingPolicies> fetchBookingPolicies(String workspaceId) async =>
      bookingPolicies[workspaceId] ?? const BookingPolicies();

  @override
  Future<void> setBookingPolicy(
    String workspaceId,
    String key, {
    required bool enabled,
  }) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.allowPastBookingsKey =>
        p.copyWith(allowPastBookings: enabled),
      // #634: grid_within_hours is read-only legacy — no writer.
      BookingPolicies.adminCheckOutKey => p.copyWith(adminCheckOut: enabled),
      _ => p,
    };
  }

  @override
  Future<void> setLegendProfile(
    String workspaceId,
    LegendProfile profile,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(legendProfile: profile);
  }

  @override
  Future<void> setOutsideHoursMode(
    String workspaceId,
    OutsideHoursMode mode,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(outsideHoursMode: mode);
  }

  @override
  Future<void> setSimultaneousReservations(
    String workspaceId,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] =
        p.copyWith(simultaneousReservations: value);
  }

  @override
  Future<void> setBookingLimit(
    String workspaceId,
    String key,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.advanceHorizonDaysKey =>
        p.copyWith(advanceHorizonDays: value),
      BookingPolicies.minDurationMinutesKey =>
        p.copyWith(minDurationMinutes: value),
      BookingPolicies.maxDurationMinutesKey =>
        p.copyWith(maxDurationMinutes: value),
      _ => p,
    };
  }

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async =>
      closureDays.where((c) => c.workspaceId == workspaceId).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

  @override
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final closure = ClosureDay(
      id: 'closure-${nextId++}',
      workspaceId: workspaceId,
      day: DateTime(day.year, day.month, day.day),
      reason: reason,
    );
    closureDays.add(closure);
    return closure;
  }

  @override
  Future<void> removeClosureDay(String closureDayId) async {
    closureDays.removeWhere((c) => c.id == closureDayId);
  }

  @override
  Future<HolidayGeneration> generateClosureDays(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  }) async {
    holidayCalls.add((country: country, year: year, apply: apply));
    if (!apply) {
      return HolidayGeneration(
        days: holidayGeneration.days,
        lockedMonths: holidayGeneration.lockedMonths,
        created: 0,
      );
    }
    var created = 0;
    for (final d in holidayGeneration.creatable) {
      closureDays.add(ClosureDay(
        id: 'closure-${nextId++}',
        workspaceId: workspaceId,
        day: d.day,
        reason: d.key,
      ));
      created++;
    }
    return HolidayGeneration(
      days: holidayGeneration.days,
      lockedMonths: holidayGeneration.lockedMonths,
      created: created,
    );
  }

  @override
  Future<HolidayGeneration> importClosureDays(
    String workspaceId, {
    required List<({DateTime day, String name})> days,
    bool apply = false,
  }) async {
    holidayImportCalls.add((days: List.of(days), apply: apply));
    String month(DateTime d) => yearMonth(d.year, d.month);
    bool present(DateTime d) => closureDays.any(
        (c) => c.workspaceId == workspaceId && c.day == d);
    final answer = [
      for (final d in days)
        (
          day: d.day,
          key: d.name,
          locked: invoicedMonths.contains(month(d.day)),
          present: present(d.day),
        ),
    ];
    var created = 0;
    if (apply) {
      for (final d in answer.where((d) => !d.locked && !d.present)) {
        closureDays.add(ClosureDay(
          id: 'closure-${nextId++}',
          workspaceId: workspaceId,
          day: d.day,
          reason: d.key,
        ));
        created++;
      }
    }
    return HolidayGeneration(
      days: answer,
      lockedMonths: {
        for (final d in answer)
          if (d.locked) month(d.day),
      }.toList()
        ..sort(),
      created: created,
    );
  }

  @override
  Future<String?> fetchDefaultPeriod(String workspaceId) async =>
      workspaceDefaultPeriods[workspaceId];

  @override
  Future<void> setDefaultPeriod(String workspaceId, String? wire) async {
    workspaceDefaultPeriods[workspaceId] = (wire ?? '').isEmpty ? null : wire;
  }
}
