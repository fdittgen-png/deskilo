// SPDX-License-Identifier: 0BSD
//
// The field bug (#417): with a real workspace timezone INSTALLED, the
// full-day window's start is a TZDateTime (workspace midnight) — and
// `TZDateTime.toLocal()` converts to package:timezone's `tz.local`,
// which DEFAULTS TO UTC because nothing ever calls setLocalLocation.
// Paris midnight Monday = 22:00 Sunday UTC → "Fermé ce jour-là" on an
// open Monday. No prior test installed a timezone, so it shipped.
//
// The open-day question is about the WORKSPACE calendar (the server's
// assert_workspace_open walks days in the workspace zone): convert via
// WorkspaceTime.dateOf, never via .toLocal().

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/workspace/domain/workspace_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #446 made the default working day 8:00–17:00, whose instants never
  // cross the UTC date line from Paris — the #417 trap needs a
  // midnight-anchored window, so this file installs one explicitly.
  setUp(() {
    WorkspaceTime.install('Europe/Paris');
    WorkHours.install(const WorkHours(
      startMinutes: 0,
      halfBoundaryMinutes: 13 * 60,
      endMinutes: 24 * 60,
      halfDayHours: 6,
      fullDayHours: 12,
    ));
  });
  tearDown(() {
    WorkspaceTime.reset();
    WorkHours.reset();
  });

  // 2026-08-03 is a Monday.
  final monday = DateTime(2026, 8, 3);
  const monToFri = [1, 2, 3, 4, 5];

  test('full-day window start on an installed-timezone Monday is OPEN '
      'through WorkspaceTime.dateOf', () {
    final window = HalfDayWindows.fullDay(monday);
    expect(
      isWorkspaceOpenOn(WorkspaceTime.dateOf(window.start), monToFri, const []),
      isTrue,
      reason: 'Paris midnight Monday is a Monday on the workspace calendar',
    );
  });

  test('the broken conversion is pinned: .toLocal() on the same window '
      'start lands on SUNDAY (tz.local defaults to UTC)', () {
    final window = HalfDayWindows.fullDay(monday);
    // This is the bug shape — kept as a tripwire: if package:timezone
    // ever changes its default local zone, or someone reintroduces
    // .toLocal() on workspace windows, this documents what happens.
    expect(window.start.toLocal().weekday, DateTime.sunday,
        reason: 'TZDateTime.toLocal() → tz.local (UTC default) → the '
            'previous calendar day for zones east of UTC');
  });

  test('morning starts at midnight too — same trap; afternoon never '
      'tripped it (13:00 Paris = 11:00 UTC, same day)', () {
    final morning = HalfDayWindows.morning(monday);
    final afternoon = HalfDayWindows.afternoon(monday);
    expect(WorkspaceTime.dateOf(morning.start).weekday, DateTime.monday);
    expect(WorkspaceTime.dateOf(afternoon.start).weekday, DateTime.monday);
    expect(afternoon.start.toLocal().weekday, DateTime.monday,
        reason: 'why the bug looked random: only midnight-anchored '
            'windows crossed the UTC date line');
  });

  test('display() keeps workspace wall-clock times readable', () {
    final window = HalfDayWindows.afternoon(monday);
    expect(WorkspaceTime.display(window.start).hour, 13,
        reason: 'a 13:00 Paris window says 13:00, not 11:00');
  });
}
