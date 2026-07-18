// SPDX-License-Identifier: MIT
//
// Booking windows must anchor to the WORKSPACE timezone, not the
// device's — found the hard way: a US/Pacific laptop booking a
// Europe/Paris workspace built "full days" running 09:00–09:00 Paris
// time, which enforce_booking_rules rightly rejects (the half-day
// error the owner screenshotted).
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(WorkspaceTime.reset);

  test('uninstalled: windows stay device-local (co-located behavior)', () {
    final window = HalfDayWindows.fullDay(DateTime(2026, 7, 20));
    expect(window.start, DateTime(2026, 7, 20));
    expect(window.end, DateTime(2026, 7, 21));
  });

  test('installed: the full day is the WORKSPACE\'s midnights, whatever '
      'the device zone', () {
    WorkspaceTime.install('Europe/Paris');

    final window = HalfDayWindows.fullDay(DateTime(2026, 7, 20));
    // Paris midnight in July = 22:00 UTC of the previous day (CEST).
    expect(window.start.toUtc(), DateTime.utc(2026, 7, 19, 22));
    expect(window.end.toUtc(), DateTime.utc(2026, 7, 20, 22));
  });

  test('morning/afternoon pivot at 13:00 workspace time', () {
    WorkspaceTime.install('Europe/Paris');

    final morning = HalfDayWindows.morning(DateTime(2026, 7, 20));
    final afternoon = HalfDayWindows.afternoon(DateTime(2026, 7, 20));
    expect(morning.end.toUtc(), DateTime.utc(2026, 7, 20, 11)); // 13:00 CEST
    expect(afternoon.start, morning.end);
    expect(afternoon.end.toUtc(), DateTime.utc(2026, 7, 20, 22));
  });

  test('windowForNow uses the workspace-local date — near midnight it '
      'differs from the device date', () {
    WorkspaceTime.install('Europe/Paris');

    // 22:30 UTC on Jul 19 = 00:30 Paris on Jul 20: the walk-up belongs
    // to Paris' Jul 20 morning, ending 13:00 CEST.
    final window =
        HalfDayWindows.windowForNow(DateTime.utc(2026, 7, 19, 22, 30));
    expect(window.start.toUtc(), DateTime.utc(2026, 7, 19, 22));
    expect(window.end.toUtc(), DateTime.utc(2026, 7, 20, 11));
  });

  test('an unknown zone name falls back to device-local', () {
    WorkspaceTime.install('Not/AZone');
    final window = HalfDayWindows.fullDay(DateTime(2026, 7, 20));
    expect(window.start, DateTime(2026, 7, 20));
  });
}
