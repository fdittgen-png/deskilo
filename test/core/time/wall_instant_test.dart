// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — a position in a grid becomes an instant through the
// business's zone, and the two days a calendar cannot hide are explicit: the
// hour that does not exist (29 March 2026 in Paris, 02:30) and the hour that
// happens twice (25 October 2026, 02:30). The axis counts elapsed time, so a
// day with a clock change is 23 or 25 hours long, and says where the wall
// clock jumps or repeats.
import 'package:deskilo/core/time/day_axis.dart';
import 'package:deskilo/core/time/wall_instant.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;
  late tz.Location newYork;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    newYork = tz.getLocation('America/New_York');
  });

  group('resolveWallTime', () {
    test('an ordinary wall time names one instant', () {
      final r = resolveWallTime(paris, 2026, 11, 12, 9, 30);
      expect(r, isA<WallExact>());
      expect((r as WallExact).instant.toUtc(), DateTime.utc(2026, 11, 12, 8, 30));
    });

    test('the hour the clocks skip does not exist: nothing is chosen', () {
      final r = resolveWallTime(paris, 2026, 3, 29, 2, 30);
      expect(r, isA<WallGap>());
      final gap = r as WallGap;
      // Read with the winter offset it is 03:30 summer time; with the summer
      // offset, 01:30 winter time. Both are offered, neither is picked.
      expect(gap.forward.toUtc(), DateTime.utc(2026, 3, 29, 1, 30));
      expect(gap.backward.toUtc(), DateTime.utc(2026, 3, 29, 0, 30));
    });

    test('the hour the clocks repeat names two real instants', () {
      final r = resolveWallTime(paris, 2026, 10, 25, 2, 30);
      expect(r, isA<WallFold>());
      final fold = r as WallFold;
      expect(fold.first.toUtc(), DateTime.utc(2026, 10, 25, 0, 30));
      expect(fold.second.toUtc(), DateTime.utc(2026, 10, 25, 1, 30));
    });

    test('the zone is the one given, not the device\'s', () {
      // 02:30 on 8 March 2026 does not exist in New York either; in Paris it
      // is an ordinary night.
      expect(resolveWallTime(newYork, 2026, 3, 8, 2, 30), isA<WallGap>());
      expect(resolveWallTime(paris, 2026, 3, 8, 2, 30), isA<WallExact>());
    });

    test('the minutes either side of a change are exact', () {
      expect(resolveWallTime(paris, 2026, 3, 29, 1, 59), isA<WallExact>());
      expect(resolveWallTime(paris, 2026, 3, 29, 3), isA<WallExact>());
      expect(resolveWallTime(paris, 2026, 10, 25, 1, 59), isA<WallExact>());
      expect(resolveWallTime(paris, 2026, 10, 25, 3), isA<WallExact>());
    });
  });

  group('buildDayAxis', () {
    DayAxis axis(int y, int m, int d, {int from = 0, int to = 24 * 60}) =>
        buildDayAxis(paris, DateTime(y, m, d), startMinutes: from, endMinutes: to);

    test('an ordinary day is 24 hours and 24 marks', () {
      final a = axis(2026, 11, 12);
      expect(a.minutes, 24 * 60);
      expect(a.ticks, hasLength(24));
      expect(a.hasClockChange, isFalse);
    });

    test('the day the clocks go forward is 23 hours and marks the jump', () {
      final a = axis(2026, 3, 29);
      expect(a.minutes, 23 * 60);
      expect(a.ticks, hasLength(23));
      final after = a.ticks.where((t) => t.afterGap).toList();
      expect(after, hasLength(1));
      expect(after.single.wallMinutes, 3 * 60); // 01:00 is followed by 03:00
      expect(a.ticks.where((t) => t.wallMinutes == 2 * 60), isEmpty);
    });

    test('the day the clocks go back is 25 hours and repeats 02:00', () {
      final a = axis(2026, 10, 25);
      expect(a.minutes, 25 * 60);
      expect(a.ticks, hasLength(25));
      final two = a.ticks.where((t) => t.wallMinutes == 2 * 60).toList();
      expect(two, hasLength(2));
      expect(two.first.repeated, isFalse);
      expect(two.last.repeated, isTrue);
      // The two 02:00 are an hour apart on the axis.
      expect(two.last.instant.difference(two.first.instant).inMinutes, 60);
    });

    test('a position is one instant: the same offset never lands twice', () {
      final a = axis(2026, 10, 25);
      final instants = {for (var m = 0; m < a.minutes; m += 60) a.instantAt(m)};
      expect(instants, hasLength(25));
      expect(a.offsetOf(a.instantAt(3 * 60)), 3 * 60);
    });

    test('the opening hours of a day without a change are as long as given', () {
      final a = axis(2026, 11, 12, from: 8 * 60, to: 17 * 60);
      expect(a.minutes, 9 * 60);
      expect(a.ticks.first.wallMinutes, 8 * 60);
      expect(a.hasClockChange, isFalse);
    });

    test('an opening that starts in the skipped hour starts after it', () {
      final a = axis(2026, 3, 29, from: 2 * 60 + 30, to: 6 * 60);
      expect(a.start.toUtc(), DateTime.utc(2026, 3, 29, 1, 30)); // 03:30 local
    });
  });
}
