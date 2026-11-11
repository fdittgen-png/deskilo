// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 release 1 -- the home says only what it read. A source of the
// invoices' statuses that failed is named with Try again, and no figure,
// list or action read from it is shown as if it had been read. Each "To
// do" entry opens the list of exactly what it counts.
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _today = DateTime(2026, 11, 10);

Receivable _r(
  String no, {
  required String due,
  String customer = 'Atelier Nord',
  int sent = 0,
  int? dueLevel,
  bool declared = false,
  bool toMatch = false,
  ReceivableStage stage = ReceivableStage.open,
}) => Receivable(
  invoiceId: no,
  customerId: customer,
  customerName: customer,
  number: '2026-$no',
  currency: 'CHF',
  totalMinor: 10000,
  openMinor: 10000,
  issuedOn: DateTime.parse(due).subtract(const Duration(days: 14)),
  dueOn: DateTime.parse(due),
  stage: stage,
  remindersSent: sent,
  reminderDueLevel: dueLevel,
  paymentDeclared: declared,
  paymentToMatch: toMatch,
);

/// Overdue invoices of which only some have a reminder due, declared and
/// to-match payments, and invoices that wait on nothing.
final _sample = [
  _r('01', due: '2026-09-21', sent: 1, dueLevel: 2),
  _r('02', due: '2026-09-23', customer: 'Studio Sud', dueLevel: 1),
  _r('03', due: '2026-10-01', customer: 'Kontor', sent: 3),
  _r('04', due: '2026-10-12', customer: 'Linea', declared: true),
  _r('05', due: '2026-10-14', customer: 'Kontor', declared: true),
  _r('06', due: '2026-10-20', customer: 'Praxis', toMatch: true),
  _r('07', due: '2026-11-25', customer: 'Praxis'),
];

InvoicingHomeData _data({Set<InvoicingSource> failed = const {}}) =>
    InvoicingHomeData(
      receivables: _sample,
      today: _today,
      month: 'November',
      currency: 'CHF',
      mode: ReminderMode.byHand,
      failed: failed,
    );

InvoicingHomeActions _actions({
  ValueChanged<InvoicingSource>? onRetry,
  ValueChanged<TodoKind>? onTodo,
}) => InvoicingHomeActions(
  onOpenInvoice: (_) {},
  onOpenCustomer: (_) {},
  onCustomerAction: (_, _) {},
  onTodo: onTodo ?? (_) {},
  onRetry: onRetry ?? (_) {},
  onNewInvoice: () {},
);

Future<void> _pump(
  WidgetTester tester,
  InvoicingHomeData data, {
  ValueChanged<InvoicingSource>? onRetry,
  ValueChanged<TodoKind>? onTodo,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: InvoicingHome(
        data: data,
        actions: _actions(onRetry: onRetry, onTodo: onTodo),
      ),
    ),
    size: const Size(800, 3000),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a failed read of the matches shows no figure, list or action, '
      'and Try again reads it again', (tester) async {
    final retried = <InvoicingSource>[];
    await _pump(
      tester,
      _data(failed: {InvoicingSource.matches}),
      onRetry: retried.add,
    );

    expect(find.byKey(const ValueKey('invoicing-failed-matches')), findsOne);
    expect(find.byKey(const ValueKey('invoicing-owed')), findsNothing);
    expect(find.byKey(const ValueKey('invoicing-todo')), findsNothing);
    expect(find.byKey(const ValueKey('invoicing-list')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invoicing-retry-matches')));
    expect(retried, [InvoicingSource.matches]);
  });

  testWidgets('a failed read of the payment history keeps the invoices and '
      'withholds only Received', (tester) async {
    await _pump(tester, _data(failed: {InvoicingSource.payments}));

    expect(find.byKey(const ValueKey('invoicing-failed-payments')), findsOne);
    expect(find.byKey(const ValueKey('invoicing-owed')), findsOne);
    expect(find.byKey(const ValueKey('invoicing-list')), findsOne);
  });

  test('the reader names a status source that failed', () async {
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(money: FakeMoneyRepository()),
        invoiceMatchesProvider.overrideWith(
          (ref) async => throw StateError('the matches could not be read'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(invoicingFailedSourcesProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(invoiceMatchesProvider.future),
      throwsStateError,
    );
    expect(container.read(invoicingFailedSourcesProvider), {
      InvoicingSource.matches,
    });
  });

  test('a customer holding money not assigned is matched first, never '
      'reminded', () {
    final reminded = _sample.firstWhere((r) => r.invoiceId == '01');
    expect(todoKindOf(reminded, ReminderMode.byHand), TodoKind.shareReminders);
    expect(
      todoKindOf(
        reminded,
        ReminderMode.byHand,
        holdsUnassigned: {reminded.customerId},
      ),
      TodoKind.matchPayments,
    );
  });

  testWidgets('each To do entry opens the list of exactly what it counts; '
      'the reminders by hand open their queue', (tester) async {
    final opened = <TodoKind>[];
    await _pump(tester, _data(), onTodo: opened.add);
    final l = AppLocalizations.of(tester.element(find.byType(InvoicingHome)))!;
    final todo = todoOf(_sample, mode: ReminderMode.byHand);
    expect(
      todo.map((t) => t.kind),
      containsAll([
        TodoKind.shareReminders,
        TodoKind.confirmPayments,
        TodoKind.matchPayments,
      ]),
    );
    for (final t in todo) {
      await tester.tap(find.byKey(ValueKey('invoicing-todo-${t.kind.name}')));
      await tester.pumpAndSettle();
      if (t.kind == TodoKind.shareReminders) {
        expect(opened.last, TodoKind.shareReminders, reason: 'the queue');
        continue;
      }

      final customers = {
        for (final r in _sample)
          if (todoKindOf(r, ReminderMode.byHand) == t.kind) r.customerId,
      }.length;
      expect(
        find.text(
          l.invoicingCountLine(
            l.invoicingCustomerCount(customers),
            l.invoicingInvoiceCount(t.tally.count),
          ),
        ),
        findsOne,
        reason: '${t.kind.name}: the list holds what the entry counts',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('invoicing-todo-selected')),
          matching: find.byTooltip('Close'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('invoicing-todo-selected')),
        findsNothing,
      );
    }
  });
}
