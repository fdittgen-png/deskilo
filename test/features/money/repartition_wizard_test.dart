// SPDX-License-Identifier: 0BSD
//
// #934 — the guided repartition proposes shares by subscription
// percentage that add up to the cost exactly, and remembers the rule.
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/presentation/screens/repartition_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('cost → rule (shares by subscription share) → book, rule remembered',
      (tester) async {
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const MaterialApp(home: RepartitionWizardScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('wizard-title')), 'Internet');
    await tester.enterText(find.byKey(const ValueKey('wizard-amount')), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Every active member gets a share, and the shares add up to 100.00.
    final total = tester.widget<ListTile>(find.byKey(const ValueKey('wizard-shares-total')));
    expect((total.trailing! as Text).data, contains('100'));
    expect(find.byKey(const ValueKey('wizard-method')), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-book')));
    await tester.pumpAndSettle();

    expect(money.repartitionRule.method, RepartitionMethod.subscription,
        reason: 'the rule is remembered by default');
  });
}
