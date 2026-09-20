// SPDX-License-Identifier: AGPL-3.0-or-later
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

    // #1532 — this used to be the file's only closing assertion, and it
    // could not fail: `RepartitionRule()` DEFAULTS to `subscription`, so
    // it passed on the fake's initial value whether or not Book wrote
    // anything. It did not: `_pool()` read two auto-disposed async
    // providers that nothing was subscribed to, so the share list was
    // empty and `_book` returned before writing. The button was offered
    // and did nothing.
    expect(money.repartitions, hasLength(1),
        reason: 'the cost is actually shared — the assertion below cannot '
            'see the difference, because the value it checks is also the '
            'default');
    expect(money.repartitions.single.title, 'Internet');
    expect(money.repartitionRule.method, RepartitionMethod.subscription,
        reason: 'the rule is remembered by default');
  });
}
