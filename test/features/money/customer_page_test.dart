// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-g -- one customer as a person meets it: what they owe in each
// currency (never one sum), their credit only when it was read, their invoices
// in the words of the home's lines, their story, and the one next action in the
// bottom bar; no rule of the experience breaks at 320, 390 and 1280 px.
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/customer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../ux/experience_guards.dart';

final _today = DateTime(2026, 11, 10);

Receivable _inv(
  String id, {
  String customer = 'kalo',
  String currency = 'EUR',
  int open = 12000,
  ReceivableStage stage = ReceivableStage.open,
  DateTime? issued,
  DateTime? due,
  DateTime? paid,
  int reminders = 0,
  int? dueLevel,
  bool declared = false,
}) => Receivable(
  invoiceId: id,
  customerId: customer,
  customerName: customer == 'kalo' ? 'SASU KaloA' : 'Other',
  number: '2026-$id',
  currency: currency,
  totalMinor: 12000,
  openMinor: open,
  issuedOn: issued ?? DateTime(2026, 9, 7),
  stage: stage,
  dueOn: due ?? DateTime(2026, 9, 21),
  paidOn: paid,
  remindersSent: reminders,
  reminderDueLevel: dueLevel,
  paymentDeclared: declared,
);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(
  WidgetTester tester,
  List<Receivable> all, {
  ReminderMode mode = ReminderMode.byHand,
  Map<String, int>? credit,
  Size size = const Size(390, 844),
  void Function(String)? onInvoice,
  void Function(InvoiceAction)? onAction,
  List<PaymentLeft> payments = const [],
  void Function(PaymentLeft)? onAssign,
}) async {
  await pumpApp(
    tester,
    CustomerPage(
      customerId: 'kalo',
      receivables: all,
      today: _today,
      mode: mode,
      credit: credit,
      payments: payments,
      onAssign: onAssign,
      onOpenInvoice: onInvoice ?? (_) {},
      onAction: onAction ?? (_) {},
    ),
    size: size,
    overrides: standardTestOverrides(),
  );
  await tester.pumpAndSettle();
}

void main() {
  final invoices = [
    _inv('0063', reminders: 1, dueLevel: 2),
    _inv(
      '0058',
      stage: ReceivableStage.paid,
      open: 0,
      issued: DateTime(2026, 8, 5),
      due: DateTime(2026, 8, 19),
      paid: DateTime(2026, 8, 25),
    ),
    _inv('0070', currency: 'CHF', open: 8000, due: DateTime(2026, 12, 20)),
    _inv('0001', customer: 'other'),
  ];

  testWidgets('each currency is owed on its own, never as one sum', (
    tester,
  ) async {
    await _pump(tester, invoices);
    expect(find.text('SASU KaloA'), findsOneWidget);
    expect(_key('customer-page-owed-EUR'), findsOneWidget);
    expect(_key('customer-page-owed-CHF'), findsOneWidget);
    expect(find.textContaining('€120.00'), findsWidgets);
    expect(find.textContaining('CHF'), findsWidgets);
    expect(find.text('€200.00'), findsNothing);
  });

  testWidgets('only this customer\'s invoices are listed, in the words of the '
      'home', (tester) async {
    await _pump(tester, invoices);
    expect(_key('customer-page-invoice-0063'), findsOneWidget);
    expect(_key('customer-page-invoice-0058'), findsOneWidget);
    expect(_key('customer-page-invoice-0070'), findsOneWidget);
    expect(_key('customer-page-invoice-0001'), findsNothing);
    expect(find.textContaining('days late'), findsWidgets);
  });

  testWidgets('a tap on an invoice opens it', (tester) async {
    String? opened;
    await _pump(tester, invoices, onInvoice: (id) => opened = id);
    await tester.tap(_key('customer-page-invoice-0063'));
    expect(opened, '0063');
  });

  testWidgets('the credit is shown when read and absent when not read', (
    tester,
  ) async {
    await _pump(tester, invoices);
    expect(_key('customer-page-credit'), findsNothing);
    await _pump(tester, invoices, credit: {'EUR': 9900});
    expect(find.text('Credit: €99.00'), findsOneWidget);
  });

  testWidgets('the story names issue, reminder and payment, and where it '
      'stands now', (tester) async {
    await _pump(tester, invoices);
    expect(find.text('Invoice 2026-0058 issued'), findsOneWidget);
    expect(find.text('Invoice 2026-0058 paid'), findsOneWidget);
    expect(find.text('Reminder shared for 2026-0063'), findsOneWidget);
    expect(find.textContaining('Now:'), findsOneWidget);
  });

  testWidgets('the next action is the one filled button of the bar', (
    tester,
  ) async {
    InvoiceAction? ran;
    // Read, and nothing held: the reminder is the next action.
    await _pump(
      tester,
      invoices,
      credit: const {'EUR': 0},
      onAction: (a) => ran = a,
    );
    expect(find.text('Remind'), findsOneWidget);
    await tester.tap(_key('customer-page-action'));
    expect(ran, InvoiceAction.shareReminder);
  });

  testWidgets('the credit line offers "Assign" for each payment left, with '
      'what is left of it (#3671)', (tester) async {
    final entry = LedgerEntry(
      id: 'p1',
      memberId: 'kalo',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: 12000,
      description: 'Transfer',
      period: '2026-03',
      createdAt: DateTime(2026, 3, 20),
    );
    final left = PaymentLeft.of(entry, const PaymentUse(usedCents: {'p1': 7000}));
    PaymentLeft? assigned;
    await _pump(
      tester,
      invoices,
      credit: {'EUR': 5000},
      payments: [left],
      onAssign: (p) => assigned = p,
    );
    expect(find.text('Assign €50.00 to invoices'), findsOneWidget);
    await tester.tap(_key('customer-page-credit-assign-p1'));
    expect(assigned?.id, 'p1');
  });

  testWidgets('while the credit is not read, no Remind is offered', (
    tester,
  ) async {
    await _pump(tester, invoices);
    expect(find.text('Remind'), findsNothing);
  });

  testWidgets('money held unassigned in a currency with an open invoice: the '
      'bar says Match the payment, not Remind', (tester) async {
    InvoiceAction? ran;
    await _pump(
      tester,
      invoices,
      credit: {'EUR': 9900},
      onAction: (a) => ran = a,
    );
    expect(
      find.text('Match the payment'),
      findsNWidgets(2),
      reason: 'bar + credit card',
    );
    expect(find.text('Remind'), findsNothing);
    await tester.tap(_key('customer-page-action'));
    expect(ran, InvoiceAction.match);
    ran = null;
    await tester.tap(_key('customer-page-credit-match'));
    expect(ran, InvoiceAction.match);
  });

  testWidgets('credit in a currency they owe nothing in does not change the '
      'bar', (tester) async {
    await _pump(tester, [invoices.first], credit: {'CHF': 5000});
    expect(find.text('Remind'), findsOneWidget);
    expect(find.text('Match the payment'), findsNothing);
  });

  testWidgets('a date of another year says its year', (tester) async {
    await _pump(tester, [
      _inv(
        '0040',
        stage: ReceivableStage.paid,
        open: 0,
        issued: DateTime(2025, 8, 5),
        due: DateTime(2025, 8, 19),
        paid: DateTime(2025, 8, 25),
      ),
      _inv('0063'),
    ], size: const Size(390, 3000));
    expect(find.textContaining('Aug 19, 2025'), findsOneWidget);
    expect(find.textContaining('Aug 25, 2025'), findsWidgets);
    expect(
      find.textContaining('due Sep 21'),
      findsOneWidget,
      reason: 'this year: no year',
    );
  });

  testWidgets('a customer who owes nothing says so and has no bar', (
    tester,
  ) async {
    await _pump(tester, [
      _inv(
        '0058',
        stage: ReceivableStage.paid,
        open: 0,
        paid: DateTime(2026, 8, 25),
      ),
    ]);
    expect(_key('customer-page-nothing-owed'), findsOneWidget);
    expect(_key('customer-page-action'), findsNothing);
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('the page keeps the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        invoices,
        credit: {'EUR': 9900},
        size: Size(width, 3000),
      );
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }

  // The picture a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: a customer in two currencies, with credit', (
    tester,
  ) async {
    await loadSheetFonts();
    await _pump(tester, invoices, credit: {'EUR': 9900});
    await writeSheet(tester, sheet: 'customer-page', name: 'customer');
  });
}
