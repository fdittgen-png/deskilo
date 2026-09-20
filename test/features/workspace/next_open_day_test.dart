// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1196 — the closed-day banner has to have somewhere to point.
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/domain/next_open_day.dart';
import 'package:flutter_test/flutter_test.dart';

ClosureDay _closed(int y, int m, int d) => ClosureDay(
      id: 'c-$y$m$d',
      workspaceId: 'ws-1',
      day: DateTime(y, m, d),
      reason: 'Holiday',
    );

const weekdays = [1, 2, 3, 4, 5];

void main() {
  test('an open day answers itself — the banner is not shown then, but '
      'the rule must not skip ahead when it is called', () {
    // Monday 14 September 2026.
    final monday = DateTime(2026, 9, 14);
    expect(
      nextOpenDay(monday, openWeekdays: weekdays, closures: const []),
      monday,
    );
  });

  test('a Sunday points at the Monday after it — the case the whole '
      'screenshot batch was shot on', () {
    expect(
      nextOpenDay(DateTime(2026, 9, 13),
          openWeekdays: weekdays, closures: const []),
      DateTime(2026, 9, 14),
    );
  });

  test('a closure on that Monday moves the answer to the Tuesday', () {
    expect(
      nextOpenDay(
        DateTime(2026, 9, 13),
        openWeekdays: weekdays,
        closures: [_closed(2026, 9, 14)],
      ),
      DateTime(2026, 9, 15),
    );
  });

  test('a whole closed week is walked through, not given up on', () {
    expect(
      nextOpenDay(
        DateTime(2026, 9, 13),
        openWeekdays: weekdays,
        closures: [for (var d = 14; d <= 18; d++) _closed(2026, 9, d)],
      ),
      DateTime(2026, 9, 21),
      reason: 'the Monday of the week after',
    );
  });

  test('a workspace with no open weekday has nothing to point at', () {
    expect(
      nextOpenDay(DateTime(2026, 9, 13),
          openWeekdays: const [], closures: const []),
      isNull,
    );
  });

  test('and neither has one closed longer than the horizon', () {
    expect(
      nextOpenDay(
        DateTime(2026, 9, 13),
        openWeekdays: weekdays,
        closures: [
          for (var i = 0; i < 40; i++)
            _closed(2026, 9, 13 + i ~/ 30 * 0 + i + 1),
        ],
        within: const Duration(days: 5),
      ),
      isNull,
      reason: 'a banner with nothing to point at says only what it '
          'always said, which is the honest answer',
    );
  });

  test('the walk does not lose a day to a DST boundary', () {
    // Europe/Paris falls back on Sunday 25 October 2026.
    expect(
      nextOpenDay(DateTime(2026, 10, 25),
          openWeekdays: weekdays, closures: const []),
      DateTime(2026, 10, 26),
    );
  });
}
