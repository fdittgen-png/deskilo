// SPDX-License-Identifier: 0BSD
//
// #726 — automatic payment reminders. The rules carry the owner's
// switch; the dialog edits it; a reminder the sweep produced lands in
// the member's feed as its own event type with the invoice, the level
// and what is still due. The sweep itself is SQL (0134) and is covered
// by the live harness; here the client's side of the contract.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

void main() {
  group('DunningRules.automatic', () {
    test('defaults on, round-trips, and reads an old rule set as on', () {
      expect(const DunningRules().automatic, isTrue);
      expect(DunningRules.fromJson(const {'levels': 2}).automatic, isTrue);
      expect(DunningRules.fromJson(const {'automatic': false}).automatic,
          isFalse);
      final off = const DunningRules().copyWith(automatic: false);
      expect(DunningRules.fromJson(off.toJson()), off);
      expect(off.toJson()[DunningRules.keyAutomatic], false);
    });

    test('dueReminderLevel is the sweep\'s clock: first delay from issue, '
        'then between-days from the previous reminder, never past levels',
        () {
      const rules = DunningRules(levels: 2, firstAfterDays: 14, betweenDays: 7);
      final issued = DateTime(2026, 8, 1);
      int? due(DateTime now, {int count = 0, DateTime? last}) =>
          dueReminderLevel(
            issuedAt: issued,
            reminderCount: count,
            lastReminderAt: last,
            rules: rules,
            now: now,
          );
      expect(due(DateTime(2026, 8, 14)), isNull);
      expect(due(DateTime(2026, 8, 15)), 1);
      expect(due(DateTime(2026, 8, 20), count: 1, last: DateTime(2026, 8, 15)),
          isNull);
      expect(due(DateTime(2026, 8, 22), count: 1, last: DateTime(2026, 8, 15)),
          2);
      expect(due(DateTime(2026, 9, 30), count: 2, last: DateTime(2026, 8, 22)),
          isNull);
    });
  });

  testWidgets('the reminder rules dialog carries the automatic switch and '
      'saves it', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());
    await tester.tap(find.byKey(const ValueKey('invoice-dunning-settings')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('dunning-automatic'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dunning-save')));
    await tester.pumpAndSettle();
    expect(money.dunningRules.automatic, isFalse);
  });

  testWidgets('a reminder the sweep produced reads in the feed as its own '
      'line: level, invoice, amount', (tester) async {
    final events = FakeEventRepository()
      ..events.add(WorkspaceEvent(
        id: 'evt-rem',
        workspaceId: 'ws-1',
        type: EventType.invoiceReminder,
        action: EventAction.created,
        actorMemberId: 'member-2',
        subjectMemberId: 'member-1',
        payload: const {
          'invoice_id': 'inv-1',
          'number': 'INV-2026-0007',
          'level': 2,
          'levels': 3,
          'amount_cents': 25000,
          'currency': 'EUR',
          'automatic': true,
        },
        status: EventStatus.applied,
        createdAt: kTestNow,
      ));
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          events: events,
          workspace: workspace,
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await openAlertsTab(tester);
    expect(
      find.textContaining('Reminder 2: invoice INV-2026-0007'),
      findsOneWidget,
    );
    expect(find.textContaining('€250.00 still due'), findsOneWidget);
  });
}
