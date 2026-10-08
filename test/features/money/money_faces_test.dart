// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #720 — the Finances tab as four faces: Statement, Payments, Invoices,
// Documents. Each face shows ITS cards and ITS actions and nothing of
// the others; monthly views share the period chooser; a deep link picks the face
// through the controller; the flag off restores the single column.
// #726 — an invoice past the workspace's term reads overdue on the
// Payments and Invoices faces, with the way to settle it.
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/money/providers/money_face_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/money_faces.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
  testWidgets('Statement is first and Money tabs stay readable at 320 dp, text scale $scale',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    await pumpFaces(tester, size: const Size(320, 800));
    expect(find.byKey(const ValueKey('money-faces')), findsOneWidget);
    for (final f in MoneyFace.values) {
      expect(find.byKey(ValueKey('money-face-${f.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('money-face-body-statement')),
        findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('entitlement-card')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.byKey(const Key('entitlement-card')), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    // Read-only: no action of the other faces leaks in.
    expect(find.text('Record a payment'), findsNothing);
    expect(find.text('Add consumption'), findsNothing);
    expect(find.byKey(const ValueKey('invoices-button')), findsNothing);
    expect(find.byKey(const ValueKey('money-hint-statement')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('money-faces')),
        matching: find.byType(FittedBox)), findsNothing);
    for (final destination in MoneyFace.values) {
      await face(tester, destination);
      expect(tester.takeException(), isNull, reason: destination.name);
    }
  });
  }

  testWidgets('the Payments face fuses settling and asking', (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.payments);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Record a payment'), findsOneWidget);
    expect(find.text('Submit an expense'), findsOneWidget);
    expect(find.text('Request extra half-days'), findsOneWidget);
    expect(find.text('Add consumption'), findsOneWidget);
    expect(find.byKey(const Key('entitlement-card')), findsNothing);
    expect(find.byKey(const ValueKey('agreement-report-button')), findsNothing);
  });

  testWidgets('the Invoices face: nothing open reads as up to date',
      (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(const ValueKey('money-invoice-summary')), findsOneWidget);
    expect(find.text('Nothing open — you are up to date.'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.text('Your invoices in this workspace · All periods.'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-invoices-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoices-button')), findsNothing);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsNothing);
  });

  testWidgets('an open invoice inside the term is due, not overdue',
      (tester) async {
    final money = FakeMoneyRepository()
      ..dunningRules = const DunningRules(firstAfterDays: 14);
    final id = await openInvoice(money, ageDays: 3);
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(ValueKey('my-invoice-$id')), findsOneWidget);
    expect(find.textContaining('Due in 11 days'), findsOneWidget);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsNothing);
    expect(find.textContaining('1 open ·'), findsOneWidget);

    // The row's pay action lands on the Payments face.
    await tester.tap(find.byKey(ValueKey('my-invoice-pay-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-face-body-payments')),
        findsOneWidget);
  });

  testWidgets('overdue detail is retained without a duplicate invoice banner',
      (tester) async {
    final money = FakeMoneyRepository()
      ..dunningRules = const DunningRules(firstAfterDays: 14);
    await openInvoice(money, ageDays: 20);
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsNothing);
    expect(find.textContaining('Overdue by 6 days'), findsOneWidget);
    await face(tester, MoneyFace.payments);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsOneWidget);
    // Not on the statement: it is a read-only picture of the month.
    await face(tester, MoneyFace.statement);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsNothing);
  });

  testWidgets('a paid invoice is neither due nor overdue', (tester) async {
    final money = FakeMoneyRepository();
    final id = await openInvoice(money, ageDays: 40);
    await money.matchInvoice(
      invoiceId: id,
      paymentLedgerId:
          money.seedPayment('member-1', money.invoices.single.totalCents),
      resolution: 'exact',
    );
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsNothing);
    expect(find.byKey(ValueKey('my-invoice-pay-$id')), findsNothing);
    expect(find.text('Nothing open — you are up to date.'), findsOneWidget);
  });

  testWidgets('the Documents face holds the rest of the paperwork',
      (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.documents);
    expect(find.byKey(const ValueKey('agreement-report-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('payments-report-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('statement-pdf-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('document-library-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('invoices-button')), findsNothing);
  });

  testWidgets('an admin opening Finances runs the reminder sweep once (#726)',
      (tester) async {
    final money = await pumpFaces(tester);
    expect(money.sweeps, 1);
    await face(tester, MoneyFace.invoices);
    await face(tester, MoneyFace.statement);
    expect(money.sweeps, 1);
  });

  testWidgets('a plain member never runs the sweep', (tester) async {
    final money = await pumpFaces(tester, admin: false);
    expect(money.sweeps, 0);
  });

  testWidgets('a deep link picks the face through the controller',
      (tester) async {
    await pumpFaces(tester);
    final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('money-faces'))));
    container.read(moneyFaceControllerProvider.notifier).show(MoneyFace.invoices);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-face-body-invoices')),
        findsOneWidget);
    expect(container.read(moneyFaceControllerProvider), MoneyFace.invoices);
  });

  testWidgets('the month chooser is shared across faces', (tester) async {
    await pumpFaces(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final previous = DateTime(kTestNow.year, kTestNow.month - 1);
    final label = DateFormat.yMMMM('en').format(previous);
    expect(find.text(label), findsOneWidget);
    await face(tester, MoneyFace.payments);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('the account summary discloses unchanged credit and past-invoice details', (tester) async {
    final money = FakeMoneyRepository();
    await openInvoice(money);
    money.invoices[0] = money.invoices[0].copyWith(period: '2026-04');
    money.seedCreditNote('member-1', 30000);
    await pumpFaces(tester, money: money);
    final details = find.byKey(const ValueKey('money-account-details'));
    await tester.scrollUntilVisible(details, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('All periods · Credit, open invoices and refunds.'), findsOneWidget);
    expect(find.text('Net position'), findsNothing);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Credit on account'), findsOneWidget);
    expect(find.text(money.invoices.single.number), findsOneWidget);
    expect(find.text('2026-04'), findsOneWidget);
  });

  testWidgets('the flag off keeps the single column', (tester) async {
    await pumpFaces(tester, flags: const {'financeFaces': false});
    expect(find.byKey(const ValueKey('money-faces')), findsNothing);
    expect(find.text('Record a payment'), findsOneWidget);
    expect(find.text('Add consumption'), findsOneWidget);
  });

  // #1217 — "None of the buttons actually works." The sheet popped an
  // `InvoiceAction` and left the caller to run it; this surface, the
  // member's own Invoices face, awaited the future and threw the result
  // away. Quick view, Download PDF, Share PDF and E-invoice all closed
  // the sheet and did nothing, and the trace showed no line at all,
  // because the handler never ran.
  testWidgets('an invoice row\'s buttons actually DO something here',
      (tester) async {
    final money = FakeMoneyRepository();
    final id = await openInvoice(money, ageDays: 3);
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);

    await tester.tap(find.byKey(ValueKey('my-invoice-$id')));
    await tester.pumpAndSettle();

    final quick = find.byKey(ValueKey('invoice-quick-$id'));
    await tester.scrollUntilVisible(quick, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(quick);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('report-quick-preview')),
      findsOneWidget,
      reason: 'the sheet runs its own action now, so no surface can open '
          'it and forget to',
    );
  });
}
