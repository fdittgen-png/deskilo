// SPDX-License-Identifier: 0BSD
//
// #720 — the Finances tab as three faces: Payments, Consumption,
// Invoices. Each face shows ITS cards and ITS actions and nothing of
// the others; the period chooser is shared; a deep link picks the face
// through the controller; the flag off restores the single column.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
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
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
      ),
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

void main() {
  testWidgets('Payments is the first face: what I owe and how to pay it',
      (tester) async {
    await pumpFaces(tester);
    expect(find.byKey(const ValueKey('money-faces')), findsOneWidget);
    expect(find.byKey(const ValueKey('money-face-body-payments')),
        findsOneWidget);
    expect(find.text('Record a payment'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    // Nothing of the other faces leaks in.
    expect(find.byKey(const Key('entitlement-card')), findsNothing);
    expect(find.text('Add consumption'), findsNothing);
    expect(find.byKey(const ValueKey('invoices-button')), findsNothing);
    // The face's own help bubble, not the classic one.
    expect(find.byKey(const ValueKey('money-hint-payments')), findsOneWidget);
  });

  testWidgets('the Consumption face: this month, and what adds to it',
      (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.consumption);
    expect(find.byKey(const Key('entitlement-card')), findsOneWidget);
    expect(find.text('Add consumption'), findsOneWidget);
    expect(find.text('Request extra half-days'), findsOneWidget);
    expect(find.text('Record a payment'), findsNothing);
    expect(find.text('Balance'), findsNothing);
  });

  testWidgets('the Invoices face lists MY invoices and opens the detail',
      (tester) async {
    final money = FakeMoneyRepository();
    final id = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: currentPeriod(kTestNow),
    );
    await pumpFaces(tester, money: money);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(ValueKey('my-invoice-$id')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoices-button')), findsOneWidget);
    expect(find.text('Record a payment'), findsNothing);

    await tester.tap(find.byKey(ValueKey('my-invoice-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-detail-number')), findsOneWidget);
  });

  testWidgets('no invoice yet says so', (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(const ValueKey('my-invoices-empty')), findsOneWidget);
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
    // And the tab followed.
    expect(container.read(moneyFaceControllerProvider), MoneyFace.invoices);
  });

  testWidgets('the month chooser is shared across faces', (tester) async {
    await pumpFaces(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final previous = DateTime(kTestNow.year, kTestNow.month - 1);
    final label = DateFormat.yMMMM('en').format(previous);
    expect(find.text(label), findsOneWidget);
    await face(tester, MoneyFace.consumption);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('the flag off keeps the single column', (tester) async {
    await pumpFaces(tester, flags: const {'financeFaces': false});
    expect(find.byKey(const ValueKey('money-faces')), findsNothing);
    expect(find.text('Record a payment'), findsOneWidget);
    expect(find.text('Add consumption'), findsOneWidget);
  });
}
