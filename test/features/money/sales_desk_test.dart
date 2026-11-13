// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 (desk M1) — sales at the desk: the invoicing home's invoices as a
// records table whose footer adds exactly the open rows, per currency; a
// selection of reminders handed to the reminder queue, narrowed to it (the
// decision on #3614: the queue's states, never a "send selected" call); and
// how much of a guest pass is used.
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/reminder_queue.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _today = DateTime(2026, 11, 10);

/// The calendar day of an instant, as a business in the device's zone.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Receivable _r(
  String id, {
  String currency = 'EUR',
  int open = 10000,
  int? level = 1,
  ReceivableStage stage = ReceivableStage.open,
}) => Receivable(
  invoiceId: id,
  customerId: 'c-$id',
  customerName: 'Customer $id',
  number: 'INV-$id',
  currency: currency,
  totalMinor: 10000,
  openMinor: open,
  issuedOn: DateTime(2026, 9),
  dueOn: _today.subtract(const Duration(days: 5)),
  stage: stage,
  reminderDueLevel: level,
);

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _desk(WidgetTester tester, List<Receivable> receivables) async {
  await pumpApp(
    tester,
    Scaffold(
      body: InvoicingHome(
        wide: true,
        data: InvoicingHomeData(
          receivables: receivables,
          today: _today,
          month: 'November',
          currency: 'EUR',
          mode: ReminderMode.byHand,
        ),
        actions: InvoicingHomeActions(
          onOpenInvoice: (_) {},
          onOpenCustomer: (_) {},
          onCustomerAction: (_, _) {},
          onTodo: (_) {},
          onRetry: (_) {},
          onNewInvoice: () {},
        ),
      ),
    ),
    size: const Size(1440, 1200),
  );
  await tester.pumpAndSettle();
  // By invoice: the records table.
  await tester.tap(
    find.descendant(of: _k('invoicing-view'), matching: find.text('Invoices')),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the desk table', () {
    testWidgets('the footer adds the open rows, one total per currency, '
        'never across', (tester) async {
      await _desk(tester, [
        _r('a', open: 4000),
        _r('b', open: 6000),
        _r('c', currency: 'CHF', open: 2500),
        _r('d', open: 0, level: null, stage: ReceivableStage.paid),
      ]);
      // The Open chip: a, b and c; the paid one is not open.
      expect(_k('records-row-a'), findsOneWidget);
      expect(_k('records-row-d'), findsNothing);
      expect(
        tester.widget<Text>(_k('records-total-EUR')).data,
        contains('100.00'),
        reason: 'the open amount is the open rows: 40 + 60',
      );
      expect(
        tester.widget<Text>(_k('records-total-CHF')).data,
        contains('25.00'),
      );
      expect(find.textContaining('125'), findsNothing, reason: 'never summed');
      // The chips say their counts.
      expect(find.text('Open 3'), findsOneWidget);
      expect(find.text('Paid 1'), findsOneWidget);
    });

    testWidgets('reminders are shared from a selection: the queue is given '
        'exactly the selected invoices', (tester) async {
      Set<String>? shared;
      await pumpApp(
        tester,
        Scaffold(
          body: InvoicingHome(
            wide: true,
            data: InvoicingHomeData(
              receivables: [_r('a'), _r('b'), _r('c')],
              today: _today,
              month: 'November',
              currency: 'EUR',
              mode: ReminderMode.byHand,
            ),
            actions: InvoicingHomeActions(
              onOpenInvoice: (_) {},
              onOpenCustomer: (_) {},
              onCustomerAction: (_, _) {},
              onTodo: (_) {},
              onRetry: (_) {},
              onNewInvoice: () {},
              onShareReminders: (ids) => shared = ids,
            ),
          ),
        ),
        size: const Size(1440, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _k('invoicing-view'),
          matching: find.text('Invoices'),
        ),
      );
      await tester.pumpAndSettle();
      for (final id in ['a', 'c']) {
        await tester.tap(
          find.descendant(
            of: _k('records-row-$id'),
            matching: find.byType(Checkbox),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Share 2 reminders'), findsOneWidget);
      await tester.tap(_k('records-bulk-remind'));
      await tester.pumpAndSettle();
      expect(shared, {'a', 'c'});
    });

    testWidgets('the paid filter chosen from outside opens the table on it', (
      tester,
    ) async {
      final filter = ValueNotifier(InvoicingFilter.open);
      addTearDown(filter.dispose);
      await pumpApp(
        tester,
        Scaffold(
          body: InvoicingHome(
            wide: true,
            filter: filter,
            data: InvoicingHomeData(
              receivables: [
                _r('a'),
                _r('d', open: 0, level: null, stage: ReceivableStage.paid),
              ],
              today: _today,
              month: 'November',
              currency: 'EUR',
              mode: ReminderMode.byHand,
            ),
            actions: InvoicingHomeActions(
              onOpenInvoice: (_) {},
              onOpenCustomer: (_) {},
              onCustomerAction: (_, _) {},
              onTodo: (_) {},
              onRetry: (_) {},
              onNewInvoice: () {},
            ),
          ),
        ),
        size: const Size(1440, 1200),
      );
      await tester.pumpAndSettle();
      filter.value = InvoicingFilter.paid;
      await tester.pumpAndSettle();
      expect(_k('records-row-d'), findsOneWidget);
      expect(_k('records-row-a'), findsNothing);
    });
  });

  group('a selection of reminders', () {
    test('the queue is only the selected invoices; "check first" only their '
        'customers; what already happened stays', () {
      final invoices = [_r('a'), _r('b'), _r('c'), _r('d')];
      final queue = reminderQueueOf(
        invoices,
        _today,
        ReminderMode.byHand,
        holdsUnassigned: {'c-d'},
      ).withResult('a', ReminderHandled.sharedNotRecorded);
      expect(queue.checkFirst.map((c) => c.customerId), ['c-d']);

      final only = queue.only({'a', 'c'}, customers: {'c-a', 'c-c'});
      expect(only.lines.map((l) => l.invoiceId), ['a', 'c']);
      expect(only.checkFirst, isEmpty, reason: 'd was not selected');
      expect(
        only.unrecorded.map((l) => l.invoiceId),
        ['a'],
        reason: 'shared but not recorded: offered Record, never a second share',
      );

      final withHolder = queue.only({'a', 'd'}, customers: {'c-a', 'c-d'});
      expect(withHolder.lines.map((l) => l.invoiceId), [
        'a',
      ], reason: 'a customer holding money is matched, never reminded');
      expect(withHolder.checkFirst.map((c) => c.customerId), ['c-d']);
    });
  });

  group('a guest pass sold', () {
    GuestPassRecord pass(GuestPassUnit unit, int units) => GuestPassRecord(
      id: 'p',
      memberId: 'g',
      offerId: 'o',
      unit: unit,
      units: units,
      amountCents: 2400 * units,
      startsAt: DateTime(2026, 11, 10, 9),
      endsAt: DateTime(2026, 11, 10 + units - 1, 18),
    );

    test('a day pass counts the days begun, never more than it has', () {
      final p = pass(GuestPassUnit.day, 3);
      expect(p.usedAt(DateTime(2026, 11, 9, 23), _day), 0);
      expect(p.usedAt(DateTime(2026, 11, 10, 8), _day), 0, reason: 'not begun');
      expect(p.usedAt(DateTime(2026, 11, 10, 9, 30), _day), 1);
      expect(p.usedAt(DateTime(2026, 11, 11, 12), _day), 2);
      expect(p.usedAt(DateTime(2026, 12, 2), _day), 3);
    });

    test('an hourly pass is all used once its window began', () {
      final p = pass(GuestPassUnit.hour, 1);
      expect(p.usedAt(DateTime(2026, 11, 10, 8, 59), _day), 0);
      expect(p.usedAt(DateTime(2026, 11, 10, 9), _day), 1);
    });
  });
}
