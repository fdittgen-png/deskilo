// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3349 — matching a payment to an invoice never offers a credit that was
// moved to another member (neither the original nor its reversal), and if the
// server refuses one anyway because the list was stale, the refusal is said in
// its own words rather than as a generic failure.

import 'package:deskilo/core/demo/data/money/demo_credit_moves.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// The server refuses the match: the credit was moved after the list was read.
class _MovedMeanwhile extends FakeMoneyRepository {
  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
    int? amountCents,
  }) async => throw const PostgrestException(
    message: 'this credit was moved: it cannot pay an invoice',
    code: '22023',
  );
}

/// #3587 R1-d — the match dialog from the invoice page's bottom bar,
/// opened on the home.
Future<void> _openMatch(WidgetTester tester, String invoiceId) async {
  await openInvoice(tester, invoiceId);
  await tester.tap(find.byKey(const ValueKey('invoice-page-match')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a moved credit is not offered; one that was not moved is', (
    tester,
  ) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    final stays = money.seedPayment('member-1', invoice.totalCents);
    final moved = money.seedPayment('member-1', invoice.totalCents);
    final moves = DemoCreditMoves(money);
    final move = await moves.moveCredit(
      creditId: moved,
      toMemberId: 'member-2',
      reason: 'paid by the colleague',
      requestId: 'r-1',
    );
    await pumpInvoices(
      tester,
      money: money,
      creditMoves: moves,
      events: registeredPayment('member-1', invoice.totalCents),
    );

    await _openMatch(tester, invoice.id);

    expect(find.byKey(ValueKey('invoice-match-payment-$stays')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-match-payment-$moved')), findsNothing);
    expect(
      find.byKey(ValueKey('invoice-match-payment-${move.reversalId}')),
      findsNothing,
    );
  });

  testWidgets('a credit moved after the list was read is refused in its own '
      'words', (tester) async {
    final money = _MovedMeanwhile();
    final id = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: currentTestPeriod(),
    );
    final pay = money.seedPayment('member-1', money.invoices.single.totalCents);
    await pumpInvoices(
      tester,
      money: money,
      events: registeredPayment('member-1', money.invoices.single.totalCents),
    );

    await _openMatch(tester, id);
    await tester.tap(find.byKey(ValueKey('invoice-match-payment-$pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This payment was moved to another member, so it cannot pay this '
        'invoice. Reload and choose another.',
      ),
      findsOneWidget,
    );
    expect(find.text('Matched'), findsNothing);
  });
}
