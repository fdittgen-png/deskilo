// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4021 — the Demo's reference business on a phone: the visitor opens the
// calendar, opens Filters and chooses two kinds. The control says two are
// chosen, the line under it names them, and the page keeps the primary row.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/calendar/calendar_kind_labels.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/navigation.dart' show tapNavIcon;
import '../helpers/screens/demo_journeys.dart' show pumpDemo;

final _en = AppLocalizationsEn();

void main() {
  testWidgets('two kinds chosen through Filters on a phone', (tester) async {
    await pumpDemo(tester, openHub: false, size: const Size(390, 844));
    await tapNavIcon(tester, Icons.calendar_month_outlined);

    await tester.ensureVisible(find.byKey(const ValueKey('calendar-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-filters')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('calendar-filters-sheet'));
    expect(sheet, findsOneWidget);
    final kinds = [
      for (final e
          in find
              .descendant(of: sheet, matching: find.byType(FilterChip))
              .evaluate())
        if ((e.widget.key as ValueKey<String>?)?.value case final key?
            when key != 'calendar-kind-all')
          key,
    ];
    expect(kinds.length, greaterThanOrEqualTo(2));
    for (final key in kinds.take(2)) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-filters')),
        matching: find.text('${_en.calendarFilters} · 2'),
      ),
      findsOneWidget,
    );
    final chosen = [
      for (final key in kinds.take(2))
        CalendarKind.values.firstWhere((k) => 'calendar-kind-${k.wire}' == key),
    ];
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-filter-summary')),
    );
    for (final kind in chosen) {
      expect(summary.data, contains(calendarKindLabel(_en, kind)));
    }
    expect(
      find.byKey(const ValueKey('calendar-my-bookings')),
      findsOneWidget,
      reason: 'the primary choice stays on the page',
    );
  });
}
