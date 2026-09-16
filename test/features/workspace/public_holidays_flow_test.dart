// SPDX-License-Identifier: 0BSD
//
// #1274 — an owner previews a year's public holidays, then confirms.
//
// The rule this file exists for: a month that already carries an invoice
// is shown as refused and is NOT offered for creation. The server decides
// that (ADR 0025); what is proved here is that the screen never invites
// an owner to do the thing the server would refuse, and never writes
// anything before the confirmation.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/public_holidays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// July is invoiced, so Bastille Day is locked; Christmas is already a
/// closure day; New Year is the only one left to create.
HolidayGeneration seededYear() => holidayGenerationFromJson(const {
      'days': [
        {'day': '2026-01-01', 'key': 'newYear', 'locked': false, 'present': false},
        {'day': '2026-07-14', 'key': 'nationalDay', 'locked': true, 'present': false},
        {'day': '2026-12-25', 'key': 'christmas', 'locked': false, 'present': true},
      ],
      'locked_months': ['2026-07'],
      'created': 0,
    });

Future<FakeWorkspaceRepository> pumpAvailability(
  WidgetTester tester, {
  required FakeWorkspaceRepository workspace,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/availability'));
  await tester.pumpAndSettle();
  return workspace;
}

FakeWorkspaceRepository withHolidays({bool on = true}) =>
    FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'publicHolidays': on},
    )..holidayGeneration = seededYear();

void main() {
  testWidgets('the action is absent until the feature is asked for',
      (tester) async {
    await pumpAvailability(tester, workspace: withHolidays(on: false));

    expect(find.byKey(const ValueKey('availability-public-holidays')),
        findsNothing,
        reason: 'publicHolidays is Platform and default OFF — generating '
            'closure days changes what a subscription includes');
  });

  testWidgets('opening the preview writes nothing', (tester) async {
    final workspace = await pumpAvailability(
      tester,
      workspace: withHolidays(),
    );

    await tester.tap(find.byKey(const ValueKey('availability-public-holidays')));
    await tester.pumpAndSettle();

    expect(workspace.holidayCalls.single.apply, isFalse,
        reason: 'the sheet opens on a PREVIEW; an apply on open would '
            'write before the owner confirmed');
    expect(workspace.closureDays, isEmpty);
  });

  testWidgets('an invoiced month is shown as refused and is not offered',
      (tester) async {
    await pumpAvailability(tester, workspace: withHolidays());

    await tester.tap(find.byKey(const ValueKey('availability-public-holidays')));
    await tester.pumpAndSettle();

    // Every day of the year is listed — including the ones it will not
    // create, because "nothing happened" is not an explanation.
    expect(find.byKey(const ValueKey('holidays-day-nationalDay')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('holidays-day-christmas')),
        findsOneWidget);
    // And the months it refused are named on screen.
    expect(find.textContaining('2026-07'), findsOneWidget,
        reason: 'the refused month is NAMED — skipping silently would be '
            'the same defect wearing a different face');
  });

  testWidgets('confirming creates only what was creatable', (tester) async {
    final workspace = await pumpAvailability(
      tester,
      workspace: withHolidays(),
    );

    await tester.tap(find.byKey(const ValueKey('availability-public-holidays')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('holidays-confirm')));
    await tester.pumpAndSettle();

    expect(workspace.holidayCalls.last.apply, isTrue);
    expect(workspace.closureDays.map((c) => c.reason), ['newYear'],
        reason: 'the locked day and the one already present are not '
            'written: one would change an issued bill, the other is a '
            'no-op');
  });
}
