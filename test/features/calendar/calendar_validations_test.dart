// SPDX-License-Identifier: 0BSD
//
// #843 — the calendar carried eleven kinds and none of them was a
// validation. A decision that released or refused an invoice, a refund
// or a deletion left no mark on the timeline. It does now, and it sits
// at the moment of the DECISION rather than of the event: the two are
// often days apart, and "when was this released" is the question.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_item_row.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'calendar_hub_test.dart' show pumpHub;

CalendarItem _decision({required bool accepted, String type = 'expense'}) =>
    CalendarItem(
      kind: CalendarKind.validation,
      id: 'dec-1',
      at: DateTime.utc(kTestNow.year, kTestNow.month, kTestNow.day, 15),
      memberId: 'member-2',
      title: '$type.${accepted ? 'validated' : 'refused'}',
      status: accepted ? 'accept' : 'reject',
      link: const EventLink('evt-1'),
    );

Future<void> _pumpRow(WidgetTester tester, CalendarItem item) async {
  // A ConsumerWidget: it reads the workspace clock and the theme tokens,
  // so it needs the same scope the app gives it.
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CalendarItemRow(
          item: item,
          memberName: 'Ana',
          onTap: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('the kind belongs to the activity family, not to money', () {
    expect(CalendarKind.validation.group, CalendarGroup.activity);
    expect(CalendarKind.validation.isMoney, isFalse);
    expect(CalendarKind.fromWire('validation'), CalendarKind.validation);
  });

  testWidgets('an accepted decision reads as validated, a refused one as '
      'refused, and both name what was decided', (tester) async {
    await _pumpRow(tester, _decision(accepted: true));
    expect(find.textContaining('Validated'), findsOneWidget);
    expect(find.textContaining('Expense'), findsOneWidget);

    await _pumpRow(tester, _decision(accepted: false));
    expect(find.textContaining('Refused'), findsOneWidget);
  });

  testWidgets('the chip is offered when the workspace wants decisions on '
      'the timeline', (tester) async {
    await pumpHub(tester);
    expect(find.byKey(const ValueKey('calendar-kind-validation')),
        findsOneWidget);
  });

  testWidgets('with the feature off the chip is gone', (tester) async {
    await pumpHub(tester, flags: const {'calendarValidations': false});
    expect(find.byKey(const ValueKey('calendar-kind-validation')),
        findsNothing);
  });
}
