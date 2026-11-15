// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4021 — on a phone the calendar's kinds sit behind one Filters control
// that says how many are chosen; its sheet chooses them at once (the list
// follows) and clears them. The Alerts control is named with its count.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/presentation/calendar_view.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_kind_chips.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_view_bar.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _filters = ValueKey('calendar-filters');

void main() {
  testWidgets('the Filters control counts the kinds chosen, its sheet '
      'chooses them at once and clears them', (tester) async {
    Set<CalendarKind>? kinds;
    final chosen = <Set<CalendarKind>?>[];
    await pumpApp(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => CalendarKindChips(
            kinds: kinds,
            offered: const [
              CalendarKind.reservation,
              CalendarKind.event,
              CalendarKind.checkIn,
            ],
            onKinds: (next) => setState(() {
              kinds = next;
              chosen.add(next);
            }),
            memberLabel: null,
            onPickMember: () {},
            myBookings: false,
            onMyBookings: () {},
            onReset: () {},
          ),
        ),
      ),
      size: const Size(390, 800),
    );
    expect(
      find.descendant(
        of: find.byKey(_filters),
        matching: find.text(_en.calendarFilters),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-kind-event')),
      findsNothing,
      reason: 'the kinds are not on the page any more',
    );

    await tester.tap(find.byKey(_filters));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-kind-reservation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-kind-event')));
    await tester.pumpAndSettle();
    expect(chosen.last, {
      CalendarKind.reservation,
      CalendarKind.event,
    }, reason: 'each choice applies at once: the list behind follows');
    expect(
      find.descendant(
        of: find.byKey(_filters),
        matching: find.text('${_en.calendarFilters} · 2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-filters-clear')));
    await tester.pumpAndSettle();
    expect(chosen.last, isNull);
  });

  testWidgets('the Alerts control is named with its count', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: CalendarViewBar(
          view: CalendarView.agenda,
          onView: (_) {},
          onToday: () {},
          alertsAvailable: true,
          onAlerts: () {},
          alertsCount: 3,
        ),
      ),
      size: const Size(800, 400),
    );
    expect(
      find.bySemanticsLabel(RegExp(_en.calendarAlertsNew(3))),
      findsOneWidget,
    );
  });
}
