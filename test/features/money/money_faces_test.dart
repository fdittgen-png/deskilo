// SPDX-License-Identifier: 0BSD
//
// #720 — the Finances tab as four faces: Statement, Payments, Invoices,
// Documents. Each face shows ITS cards and ITS actions and nothing of
// the others; the period chooser is shared; a deep link picks the face
// through the controller; the flag off restores the single column.
// #726 — an invoice past the workspace's term reads overdue on the
// Payments and Invoices faces, with the way to settle it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/money/providers/money_face_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpFaces(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  Map<String, dynamic> flags = const {},
  bool admin = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  if (!admin) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

Future<void> face(WidgetTester tester, MoneyFace face) async {
  await tester.tap(find.byKey(ValueKey('money-face-${face.name}')));
  await tester.pumpAndSettle();
}

/// An OPEN invoice for me, issued [ageDays] ago.
Future<String> openInvoice(FakeMoneyRepository money, {int ageDays = 0}) async {
  final id = await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: currentPeriod(kTestNow),
  );
  final i = money.invoices.indexWhere((x) => x.id == id);
  money.invoices[i] = money.invoices[i].copyWith(
    issuedAt: kTestNow.subtract(Duration(days: ageDays)),
  );
  return id;
}

void main() {
  testWidgets('Statement is the first face: the month as it stands',
      (tester) async {
    await pumpFaces(tester);
    expect(find.byKey(const ValueKey('money-faces')), findsOneWidget);
    for (final f in MoneyFace.values) {
      expect(find.byKey(ValueKey('money-face-${f.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('money-face-body-statement')),
        findsOneWidget);
    expect(find.byKey(const Key('entitlement-card')), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    // Read-only: no action of the other faces leaks in.
    expect(find.text('Record a payment'), findsNothing);
    expect(find.text('Add consumption'), findsNothing);
    expect(find.byKey(const ValueKey('invoices-button')), findsNothing);
    expect(find.byKey(const ValueKey('money-hint-statement')), findsOneWidget);
  });

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
    expect(find.byKey(const ValueKey('my-invoices-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoices-button')), findsOneWidget);
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

  testWidgets('past the term the invoice is overdue on both faces (#726)',
      (tester) async {
    final money = FakeMoneyRepository()
      ..dunningRules = const DunningRules(firstAfterDays: 14);
    await openInvoice(money, ageDays: 20);
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(const ValueKey('money-overdue-banner')), findsOneWidget);
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

  testWidgets('the flag off keeps the single column', (tester) async {
    await pumpFaces(tester, flags: const {'financeFaces': false});
    expect(find.byKey(const ValueKey('money-faces')), findsNothing);
    expect(find.text('Record a payment'), findsOneWidget);
    expect(find.text('Add consumption'), findsOneWidget);
  });
}
