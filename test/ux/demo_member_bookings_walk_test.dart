// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4069 — the Demo walked on a phone and at the desk: the directory's
// search finds Ada by part of her name, her page shows her next bookings
// and "All bookings (14)", and that link opens the calendar filtered to her
// (the phone's hub names her as whose calendar it is; the desk's member
// filter holds her).
import 'package:deskilo/app/desk_calendar/desk_filter_row.dart';
import 'package:deskilo/core/ui/kit/kit_metrics.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_kind_chips.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo, locationOf;

const _ada = 'Ada Lindqvist';

Future<String> _toAdasBookings(WidgetTester tester, Size size) async {
  await pumpDemo(tester, openHub: false, size: size);
  await goTo(tester, '/directory');
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('directory-search')),
      matching: find.byType(TextField),
    ),
    'lindq',
  );
  await tester.pumpAndSettle();
  expect(find.text(_ada), findsOneWidget);
  expect(find.text('Bruno Kessler'), findsNothing);
  final names = ProviderScope.containerOf(tester.element(find.text(_ada)))
      .read(memberNamesProvider)
      .requireValue;
  final id = names.entries.firstWhere((e) => e.value == _ada).key;

  await goTo(tester, '/member/$id');
  final rows = find.byWidgetPredicate(
    (w) => '${w.key}'.contains('member-page-reservation-'),
  );
  expect(rows, findsNWidgets(KitMetrics.previewRows));
  final all = find.byKey(const ValueKey('member-page-all-bookings'));
  await tester.ensureVisible(all);
  await tester.pumpAndSettle();
  expect(
    find.descendant(of: all, matching: find.text('All bookings (14)')),
    findsOneWidget,
  );
  await tester.tap(all);
  await tester.pumpAndSettle();
  expect(locationOf(tester), startsWith('/calendar'));
  return id;
}

void main() {
  testWidgets('on a phone: search, her page, her bookings in the calendar', (
    tester,
  ) async {
    await _toAdasBookings(tester, const Size(390, 844));
    expect(
      tester
          .widget<CalendarKindChips>(find.byType(CalendarKindChips))
          .memberLabel,
      _ada,
      reason: 'whose calendar it is',
    );
  });

  testWidgets('at the desk: search, her page, the calendar filtered to her', (
    tester,
  ) async {
    final id = await _toAdasBookings(tester, const Size(1440, 900));
    expect(
      find.byKey(ValueKey('desk-filter-field-member-$id')),
      findsOneWidget,
      reason: 'the member filter holds her',
    );
    expect(find.byKey(deskFilterKey('member')), findsOneWidget);
  });
}
