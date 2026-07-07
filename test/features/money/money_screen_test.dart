// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpMoney(
  WidgetTester tester, {
  FakeMoneyRepository? money,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('statement card shows plan, usage, overage and open balance',
      (tester) async {
    await pumpMoney(tester);

    expect(find.textContaining('Half'), findsOneWidget);
    expect(find.text('24 of 22 half-days used'), findsOneWidget);
    expect(find.text('Overage (2 extra half-days)'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('settled statement shows the settled chip', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      creditsCents: 20000,
      balanceCents: 3400,
    );
    await pumpMoney(tester, money: money);

    expect(find.text('Settled'), findsOneWidget);
  });

  testWidgets('recording a payment submits cents for confirmation',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '150,50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'July rent',
    );
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.amountCents, 15050);
    expect(money.recordedPayments.single.note, 'July rent');
    expect(
      find.text('Payment submitted — waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('ledger entries render with signs', (tester) async {
    final money = FakeMoneyRepository();
    money.ledger.addAll([
      LedgerEntry(
        id: 'l1',
        memberId: 'member-1',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 15000,
        description: 'June payment',
        period: '2026-06',
        createdAt: DateTime(2026, 6, 3),
      ),
      LedgerEntry(
        id: 'l2',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.overage,
        amountCents: 800,
        description: '',
        period: '2026-06',
        createdAt: DateTime(2026, 6, 30),
      ),
    ]);
    await pumpMoney(tester, money: money);

    expect(find.text('June payment'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Overage'), 100);
    expect(find.text('Overage'), findsOneWidget);
  });
}
