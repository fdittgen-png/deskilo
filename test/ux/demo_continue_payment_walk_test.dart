// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:deskilo/features/money/providers/finance_selection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

Future<void> _pumps(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _pumps(tester);
}

void main() {
  testWidgets('Chiara leaves checkout, returns to My finances and continues '
      'the same reference-organisation payment to completion', (tester) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.admin,
      openHub: false,
    );
    await goTo(tester, '/me/data?view=finances');
    await _pumps(tester);
    const invoiceId = 'demo-usage-chiara-extra';
    final money = journey.fixture.money;
    final ordersBefore = money.paymentIntents.length;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    FinanceInvoice row() => container
        .read(financeOverviewProvider)
        .requireValue
        .invoices
        .singleWhere((i) => i.id == invoiceId);
    final due = row().stillDueCents;
    await _tap(tester, 'finances-select-$invoiceId');
    await _tap(tester, 'finances-selection-pay');
    await _tap(tester, 'finances-confirm-send');
    await _tap(tester, 'demo-provider-no-answer');
    final original = money.paymentIntents.singleWhere(
      (p) => p.orderId == row().claimPaymentId,
    );
    expect(original.claimedInvoiceIds, [invoiceId]);
    expect(original.requestId, isNotEmpty);
    expect(original.amountCents, due);
    expect(row().claimCanContinue, isTrue);

    // Leave the screen and discard its request cache: continuation is read back.
    await goTo(tester, '/me');
    await _pumps(tester);
    container.invalidate(paymentRequestIdsProvider);
    await goTo(tester, '/me/data?view=finances');
    await _pumps(tester);
    await _tap(tester, 'finances-continue-$invoiceId');
    expect(money.paymentGateway.requestIds.last, original.requestId);
    expect(money.paymentIntents.length, ordersBefore + 1);
    expect(
      money.paymentIntents.singleWhere((p) => p.id == original.id).orderId,
      original.orderId,
    );
    await _tap(tester, 'demo-provider-pay');
    expect(row().state, FinanceState.paid);
    expect(row().stillDueCents, 0);
    expect(
      find.byKey(const ValueKey('finances-continue-$invoiceId')),
      findsNothing,
    );
    final credited = money.ledger.singleWhere(
      (p) => p.id == 'demo-online-${original.id}',
    );
    expect(credited.amountCents, original.amountCents);
    expect(money.invoiceMatchesStore[invoiceId]!.paymentLedgerId, credited.id);
    expect(money.paymentIntents.length, ordersBefore + 1);
  });
}
