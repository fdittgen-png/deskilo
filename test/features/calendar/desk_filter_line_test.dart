// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4075 — at the desk the calendar's filters, New booking and the overflow
// share one line at 1100, 1440 and 1920 px, so the grid starts right under
// that one line. Where the four filters do not fit, one Filters control opens
// them, says how many are in use, and shows those as chips that remove them.
// Export is reached through the overflow.
//
// test-inventory: structure is the invariant — where the grid starts is what
// a person sees of the week without scrolling.
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_filter_row.dart';
import 'package:deskilo/app/desk_calendar/desk_week_grid.dart';
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:deskilo/core/ui/kit/dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/desk_calendar.dart';

const _newKey = ValueKey('desk-new');

Iterable<DeskBookingChip> _chips(WidgetTester tester) =>
    tester.widgetList<DeskBookingChip>(find.byType(DeskBookingChip));

/// The filters' first control: the Filters control, or the first dropdown.
Finder _firstFilter() => find.byKey(deskFiltersKey).evaluate().isNotEmpty
    ? find.byKey(deskFiltersKey)
    : find.byKey(deskFilterKey('level'));

void main() {
  for (final width in [1100.0, 1440.0, 1920.0]) {
    testWidgets('at $width px the filters, New booking and ⋯ share one line '
        'and the grid starts under it', (tester) async {
      await pumpDeskCalendar(
        tester,
        size: Size(width, 900),
        query: '?view=week&day=${demoToday()}',
      );
      final bar = tester.getRect(find.byType(FilterBar));
      final grid = tester.getRect(find.byType(DeskWeekGrid));
      final line = [
        tester.getRect(_firstFilter()),
        tester.getRect(find.byKey(_newKey)),
        tester.getRect(find.byKey(deskMoreKey)),
        if (find.byKey(deskFilterKey('state')).evaluate().isNotEmpty)
          tester.getRect(find.byKey(deskFilterKey('state'))),
      ];
      for (final r in line) {
        expect(r.center.dy, closeTo(line.first.center.dy, 1), reason: '$r');
      }
      expect(
        bar.height,
        lessThanOrEqualTo(kMinInteractiveDimension + 2 * AppSpacing.sm),
        reason: 'one line, not two',
      );
      expect(grid.top, bar.bottom, reason: 'the grid starts under the line');
      expect(find.text('Export'), findsNothing, reason: 'Export is in ⋯');
    });
  }

  testWidgets('at 1100 px the Filters control opens the four filters; the one '
      'in use is counted and shown as a chip that removes it', (tester) async {
    await pumpDeskCalendar(
      tester,
      size: const Size(1100, 900),
      query: '?view=week&day=${demoToday()}',
    );
    expect(find.byKey(deskFiltersKey), findsOneWidget);
    expect(find.byKey(deskFilterKey('member')), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    final before = _chips(tester).length;
    final who = _chips(tester).first.booking.memberId;

    await tester.tap(find.byKey(deskFiltersKey));
    await tester.pumpAndSettle();
    for (final name in ['level', 'kind', 'member', 'state']) {
      expect(find.byKey(deskFilterKey(name)), findsOneWidget, reason: name);
    }
    await tester.tap(
      find.descendant(
        of: find.byKey(deskFilterKey('member')),
        matching: find.byType(DropdownButtonFormField<String?>),
      ),
    );
    await tester.pumpAndSettle();
    final item = find
        .descendant(
          of: find.byKey(ValueKey('desk-filter-member-$who')).last,
          matching: find.byType(Text),
        )
        .first;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desk-filters-close')));
    await tester.pumpAndSettle();

    expect(find.text('Filters · 1'), findsOneWidget);
    expect(find.byKey(deskFilterChipKey('member')), findsOneWidget);
    expect(_chips(tester), isNotEmpty);
    expect(_chips(tester).every((c) => c.booking.memberId == who), isTrue);
    expect(_chips(tester).length, lessThanOrEqualTo(before));

    await tester.tap(
      find.descendant(
        of: find.byKey(deskFilterChipKey('member')),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(deskFilterChipKey('member')), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    expect(_chips(tester).length, before);
  });

  testWidgets('Export is in the overflow, and offered while the period has '
      'bookings', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    await tester.tap(find.byKey(deskMoreKey));
    await tester.pumpAndSettle();
    final export = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('desk-export')),
    );
    expect(export.onPressed, isNotNull);
    expect(find.text('Export'), findsOneWidget);
  });

  test('four filters keep their line down to their narrowest width', () {
    expect(deskFilterWidth(4 * 240 + 3 * AppSpacing.md), 240);
    expect(deskFilterWidth(10000), 240);
    expect(deskFilterWidth(4 * 160 + 3 * AppSpacing.md), 160);
    expect(deskFilterWidth(4 * 160 + 3 * AppSpacing.md - 1), isNull);
  });
}
