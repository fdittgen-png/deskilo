// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1637 — the member's bill tells the truth about an online payment: a
// session the provider has not confirmed reads PENDING with its
// reference and the balance stays outstanding; a refused one reads
// FAILED and never becomes paid; only the settled statement — the
// webhook's ledger credit — reads paid, and then no attempt card shows.
// Switching member drops the previous account's attempts.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

PaymentIntent attempt(
  String id,
  String status, {
  String memberId = 'member-1',
  String? period,
}) =>
    PaymentIntent(
      id: id,
      memberId: memberId,
      provider: 'stripe',
      orderId: 'cs_test_$id',
      reference: 'PAY-2026-$id',
      period: period ?? kTestPeriod,
      amountCents: 1600,
      status: status,
      createdAt: kTestNow,
    );

Future<void> pumpMoney(
  WidgetTester tester,
  FakeMoneyRepository money, {
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(money: money, workspace: workspace),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unconfirmed session is pending, with its reference, and '
      'the balance stays outstanding', (tester) async {
    final money = FakeMoneyRepository()..paymentIntents.add(attempt('0001', 'created'));
    await pumpMoney(tester, money);

    expect(find.text('Online payment pending'), findsOneWidget);
    expect(find.textContaining('PAY-2026-0001'), findsOneWidget);
    expect(find.textContaining('€16.00 via Credit card (Stripe)'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Settled'), findsNothing);
  });

  testWidgets('a failed session says so and never reads as paid', (tester) async {
    final money = FakeMoneyRepository()..paymentIntents.add(attempt('0002', 'failed'));
    await pumpMoney(tester, money);

    expect(find.text('Online payment failed'), findsOneWidget);
    expect(find.textContaining('nothing was credited'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Online payment pending'), findsNothing);
  });

  testWidgets('only the settled statement reads paid, and a capture shows no '
      'attempt card — nor the failed try it superseded', (tester) async {
    final money = FakeMoneyRepository()
      ..paymentIntents.addAll([attempt('0003', 'failed'), attempt('0004', 'captured')]);
    money.statement = money.statement.copyWith(creditsCents: 20000, balanceCents: 0);
    await pumpMoney(tester, money);

    expect(find.text('Settled'), findsOneWidget);
    expect(find.byKey(const ValueKey('online-payment-status-card')), findsNothing);
  });

  testWidgets('another month\'s attempt is not this month\'s news', (tester) async {
    final money = FakeMoneyRepository()
      ..paymentIntents.add(attempt('0005', 'created', period: '2020-01'));
    await pumpMoney(tester, money);

    expect(find.byKey(const ValueKey('online-payment-status-card')), findsNothing);
  });

  testWidgets('switching member drops the previous account\'s attempts',
      (tester) async {
    final money = FakeMoneyRepository()
      ..paymentIntents.addAll([
        attempt('0006', 'created'),
        attempt('0007', 'created', memberId: 'member-2'),
      ]);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await pumpMoney(tester, money, workspace: workspace);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
    expect(container.read(myPaymentIntentsProvider).value!.map((i) => i.id),
        ['0006']);

    workspace.myMember = workspace.myMember.copyWith(id: 'member-2');
    container.invalidate(myMemberProvider);
    await tester.pumpAndSettle();
    expect(container.read(myPaymentIntentsProvider).value!.map((i) => i.id),
        ['0007']);
  });
}
