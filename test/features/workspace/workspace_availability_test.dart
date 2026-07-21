// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/domain/workspace_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-07-11 is a Saturday (the reported #186 repro day).
  final saturday = DateTime(2026, 7, 11);
  final monday = DateTime(2026, 7, 13);
  const weekdaysOnly = [1, 2, 3, 4, 5];
  const allDays = [1, 2, 3, 4, 5, 6, 7];

  ClosureDay closureOn(DateTime day) => ClosureDay(
        id: 'closure-1',
        workspaceId: 'ws-1',
        day: day,
        reason: 'Holiday',
      );

  group('isWorkspaceOpenOn', () {
    test('open weekday without closures is open', () {
      expect(isWorkspaceOpenOn(monday, weekdaysOnly, const []), isTrue);
    });

    test('a weekday outside open_weekdays is closed', () {
      expect(isWorkspaceOpenOn(saturday, weekdaysOnly, const []), isFalse);
    });

    test('a closure day closes an otherwise open weekday', () {
      expect(
        isWorkspaceOpenOn(monday, allDays, [closureOn(DateTime(2026, 7, 13))]),
        isFalse,
      );
    });

    test('closures on other days do not close the day', () {
      expect(
        isWorkspaceOpenOn(monday, allDays, [closureOn(DateTime(2026, 7, 14))]),
        isTrue,
      );
    });

    test('any instant of the day counts, not just midnight', () {
      final saturdayAfternoon = DateTime(2026, 7, 11, 15, 30);
      expect(
        isWorkspaceOpenOn(saturdayAfternoon, weekdaysOnly, const []),
        isFalse,
      );
      expect(
        isWorkspaceOpenOn(
          DateTime(2026, 7, 13, 15, 30),
          allDays,
          [closureOn(DateTime(2026, 7, 13))],
        ),
        isFalse,
      );
    });
  });

  test(
      'the closed-day server substring is pinned to assert_workspace_open '
      '(migration 0013)', () {
    // Both server variants — `workspace is closed on <day> (weekday not
    // open)` and `... (closure day)` — must keep matching this prefix.
    expect(WorkspaceClosedError.serverSubstring, 'workspace is closed');
  });
}
