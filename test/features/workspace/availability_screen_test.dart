// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Seed the fake BEFORE pumping — the providers cache their first read.
Future<FakeWorkspaceRepository> pumpAvailability(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
}) async {
  workspace ??= FakeWorkspaceRepository.withWorkspace();
  // The 0032 granularity radios outgrew the 800×600 default surface;
  // a taller one keeps the closure-day section hit-testable (#624 grew
  // the policies section by the outside-hours control).
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
  GoRouter.of(context).push('/availability');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('renders seven weekday chips reflecting the open weekdays',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [1, 2, 3];
    await pumpAvailability(tester, workspace: workspace);

    expect(find.byType(FilterChip), findsNWidgets(7));

    bool selectedOf(String label) => tester
        .widget<FilterChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FilterChip),
          ),
        )
        .selected;
    expect(selectedOf('Mon'), isTrue);
    expect(selectedOf('Tue'), isTrue);
    expect(selectedOf('Wed'), isTrue);
    expect(selectedOf('Thu'), isFalse);
    expect(selectedOf('Fri'), isFalse);
    expect(selectedOf('Sat'), isFalse);
    expect(selectedOf('Sun'), isFalse);
  });

  testWidgets('toggling a chip persists the new open-weekday set',
      (tester) async {
    final workspace = await pumpAvailability(tester);

    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [1, 2, 3, 4, 5, 6]);

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [2, 3, 4, 5, 6]);
  });

  testWidgets('the last open weekday cannot be unchecked', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [3];
    await pumpAvailability(tester, workspace: workspace);

    await tester.tap(find.text('Wed'));
    await tester.pump();

    expect(
      find.text('At least one weekday must stay open.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [3]);
  });

  testWidgets(
      'granularity renders every option (0032) with flexible preselected',
      (tester) async {
    await pumpAvailability(tester);

    expect(find.text('Booking granularity'), findsOneWidget);
    expect(find.text('Free time period'), findsOneWidget);
    expect(find.text('5-minute slots'), findsOneWidget);
    expect(find.text('15-minute slots'), findsOneWidget);
    expect(find.text('30-minute slots'), findsOneWidget);
    expect(find.text('1-hour slots'), findsOneWidget);
    expect(find.text('Half days (morning & afternoon)'), findsOneWidget);
    expect(find.text('Full days only'), findsOneWidget);
    final group = tester.widget<RadioGroup<BookingGranularity>>(
      find.byType(RadioGroup<BookingGranularity>),
    );
    expect(group.groupValue, BookingGranularity.flexible);
  });

  testWidgets('picking a minute slot persists that granularity (0032)',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await pumpAvailability(tester, workspace: workspace);

    await tester.ensureVisible(find.text('30-minute slots'));
    await tester.tap(find.text('30-minute slots'));
    await tester.pumpAndSettle();

    expect(
      workspace.bookingGranularities['ws-1'],
      BookingGranularity.minutes30,
    );

    await tester.ensureVisible(find.text('Full days only'));
    await tester.tap(find.text('Full days only'));
    await tester.pumpAndSettle();

    expect(
      workspace.bookingGranularities['ws-1'],
      BookingGranularity.fullDay,
    );
  });

  testWidgets(
      'switching to half days persists it and keeps the open weekdays',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [1, 3, 5];
    await pumpAvailability(tester, workspace: workspace);

    await tester.tap(find.text('Half days (morning & afternoon)'));
    await tester.pumpAndSettle();

    expect(
      workspace.bookingGranularities['ws-1'],
      BookingGranularity.halfDay,
    );
    // The granularity write must not clobber the other booking_rules keys.
    expect(workspace.openWeekdays['ws-1'], [1, 3, 5]);
    final group = tester.widget<RadioGroup<BookingGranularity>>(
      find.byType(RadioGroup<BookingGranularity>),
    );
    expect(group.groupValue, BookingGranularity.halfDay);

    // And back to flexible.
    await tester.tap(find.text('Free time period'));
    await tester.pumpAndSettle();
    expect(
      workspace.bookingGranularities['ws-1'],
      BookingGranularity.flexible,
    );
  });

  testWidgets('the hours option and the working-hours section render '
      'with the 8:00-17:00 defaults (#446)', (tester) async {
    await pumpAvailability(tester);

    await tester.ensureVisible(
        find.text('Real hours (exact from–to, half/full days as shortcuts)'));
    expect(find.text('Working hours'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-hours-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-hours-boundary')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-hours-end')), findsOneWidget);
    // The billing hour counts only appear under the hours granularity.
    expect(find.byKey(const ValueKey('work-hours-half-day-hours')),
        findsNothing);
  });

  testWidgets('under hours granularity the billing hour counts appear and '
      'the dropdown persists half_day_hours (#446)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..bookingGranularities['ws-1'] = BookingGranularity.hours;
    await pumpAvailability(tester, workspace: workspace);

    final halfTile = find.byKey(const ValueKey('work-hours-half-day-hours'));
    await tester.ensureVisible(halfTile);
    expect(find.byKey(const ValueKey('work-hours-full-day-hours')),
        findsOneWidget);

    await tester.tap(
      find.descendant(of: halfTile, matching: find.byType(DropdownButton<int>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 h').last);
    await tester.pumpAndSettle();

    expect(workspace.workHours['ws-1']?.halfDayHours, 6);
    // The write must preserve the rest of the working day.
    expect(workspace.workHours['ws-1']?.startMinutes, 8 * 60);
    expect(workspace.workHours['ws-1']?.endMinutes, 17 * 60);
  });

  testWidgets('closure days render with localized date and reason',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..closureDays.addAll([
        ClosureDay(
          id: 'closure-a',
          workspaceId: 'ws-1',
          day: DateTime(2026, 12, 24),
          reason: 'Christmas Eve',
        ),
        ClosureDay(
          id: 'closure-b',
          workspaceId: 'ws-1',
          day: DateTime(2026, 8, 15),
          reason: '',
        ),
      ]);
    await pumpAvailability(tester, workspace: workspace);

    expect(find.text('December 24, 2026'), findsOneWidget);
    expect(find.text('Christmas Eve'), findsOneWidget);
    expect(find.text('August 15, 2026'), findsOneWidget);
    expect(find.text('No closure days.'), findsNothing);
  });

  testWidgets('deleting a closure day removes it', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..closureDays.add(
        ClosureDay(
          id: 'closure-a',
          workspaceId: 'ws-1',
          day: DateTime(2026, 12, 24),
          reason: 'Christmas Eve',
        ),
      );
    await pumpAvailability(tester, workspace: workspace);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(workspace.closureDays, isEmpty);
    expect(find.text('December 24, 2026'), findsNothing);
    expect(find.text('No closure days.'), findsOneWidget);
  });

  testWidgets('adding a closure day via picker and reason dialog persists it',
      (tester) async {
    final workspace = await pumpAvailability(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // accept today in the date picker
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Deep clean');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final today = kTestNow;
    final created = workspace.closureDays.single;
    expect(created.workspaceId, 'ws-1');
    expect(created.day, DateTime(today.year, today.month, today.day));
    expect(created.reason, 'Deep clean');
    expect(find.text('Deep clean'), findsOneWidget);
  });

  testWidgets('#600 — the booking-policy switches render OFF, toggling '
      'one persists its booking_rules key', (tester) async {
    final workspace = await pumpAvailability(tester);

    final pastSwitch = find.byKey(const Key('policy-allow-past'));
    await tester.ensureVisible(pastSwitch);
    expect(tester.widget<SwitchListTile>(pastSwitch).value, isFalse);

    await tester.tap(pastSwitch);
    await tester.pumpAndSettle();
    expect(
      workspace.bookingPolicies['ws-1']?.allowPastBookings,
      isTrue,
      reason: 'the toggle writes allow_past_bookings',
    );
    expect(tester.widget<SwitchListTile>(pastSwitch).value, isTrue);

    final adminSwitch = find.byKey(const Key('policy-admin-checkout'));
    await tester.ensureVisible(adminSwitch);
    await tester.tap(adminSwitch);
    await tester.pumpAndSettle();
    expect(workspace.bookingPolicies['ws-1']?.adminCheckOut, isTrue);
    // #634: the grid switch is gone — its question is the outside-hours
    // mode's now, and the section shows no such switch any more.
    expect(find.byKey(const Key('policy-grid-hours')), findsNothing);
    expect(workspace.bookingPolicies['ws-1']?.outsideHoursMode,
        OutsideHoursMode.charged);
  });

  testWidgets('#600 — the bookingPolicies flag OFF hides the section',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'bookingPolicies': false},
    );
    await pumpAvailability(tester, workspace: workspace);
    expect(find.byKey(const Key('policy-allow-past')), findsNothing);
    expect(find.byKey(const Key('policy-grid-hours')), findsNothing);
    // #624: the outside-hours control lives in the same section.
    expect(find.byKey(const Key('policy-outside-hours')), findsNothing);
    // #628: so does the simultaneous-reservations stepper.
    expect(find.byKey(const Key('policy-simultaneous')), findsNothing);
  });

  testWidgets('#628 — the simultaneous-reservations stepper starts at 1 '
      'and stepping up writes the booking_rules key', (tester) async {
    final workspace = await pumpAvailability(tester);

    final stepper = find.byKey(const Key('policy-simultaneous'));
    await tester.ensureVisible(stepper);
    expect(
      workspace.bookingPolicies['ws-1'],
      isNull,
      reason: 'nothing written before the owner touches it',
    );
    // 1 = one place at a time, the historical behavior; there is
    // nothing below it, so the minus button is disabled.
    expect(
      tester
          .widget<IconButton>(
              find.byKey(const Key('policy-simultaneous-minus')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('policy-simultaneous-plus')));
    await tester.pumpAndSettle();
    expect(
      workspace.bookingPolicies['ws-1']?.simultaneousReservations,
      2,
      reason: 'the stepper writes simultaneous_reservations',
    );
    // The other policy keys are untouched by the merge-preserving write.
    expect(workspace.bookingPolicies['ws-1']?.allowPastBookings, isFalse);
    expect(workspace.bookingPolicies['ws-1']?.outsideHoursMode,
        OutsideHoursMode.charged);

    await tester.tap(find.byKey(const Key('policy-simultaneous-plus')));
    await tester.pumpAndSettle();
    expect(workspace.bookingPolicies['ws-1']?.simultaneousReservations, 3);

    await tester.tap(find.byKey(const Key('policy-simultaneous-minus')));
    await tester.pumpAndSettle();
    expect(workspace.bookingPolicies['ws-1']?.simultaneousReservations, 2);
  });

  testWidgets('#634 — the outside-hours control offers FOUR options with '
      'Charged preselected, and each one writes its wire value',
      (tester) async {
    final workspace = await pumpAvailability(tester);

    final control = find.byKey(const Key('policy-outside-hours'));
    await tester.ensureVisible(control);
    expect(
      tester.widget<RadioGroup<OutsideHoursMode>>(control).groupValue,
      OutsideHoursMode.charged,
      reason: 'absent booking_rules key reads as charged',
    );
    // One row per mode — the four mutually exclusive answers.
    expect(
      find.descendant(
        of: control,
        matching: find.byType(RadioListTile<OutsideHoursMode>),
      ),
      findsNWidgets(OutsideHoursMode.values.length),
    );
    // #634: the retired grid switch is not on the screen any more.
    expect(find.byKey(const Key('policy-grid-hours')), findsNothing);

    const rows = {
      'policy-outside-hours-off': OutsideHoursMode.off,
      'policy-outside-hours-walkup': OutsideHoursMode.walkupOnly,
      'policy-outside-hours-free': OutsideHoursMode.free,
      'policy-outside-hours-charged': OutsideHoursMode.charged,
    };
    for (final entry in rows.entries) {
      final row = find.byKey(Key(entry.key));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        workspace.bookingPolicies['ws-1']?.outsideHoursMode,
        entry.value,
        reason: '${entry.key} must write ${entry.value.wire}',
      );
      expect(
        tester.widget<RadioGroup<OutsideHoursMode>>(control).groupValue,
        entry.value,
      );
    }
  });

  testWidgets('#634 — the four-option control lays out on a 360dp phone',
      (tester) async {
    // A SegmentedButton of four labels overflows here; the radio rows
    // must not. 360×3600: the narrowest supported width, tall enough to
    // hold the whole screen without scrolling into the assertion.
    await tester.binding.setSurfaceSize(const Size(360, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/availability');
    await tester.pumpAndSettle();

    final control = find.byKey(const Key('policy-outside-hours'));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no overflow at 360dp');
    expect(tester.getSize(control).width, lessThanOrEqualTo(360.0));
  });
}
