// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 -- one payment may settle several invoices, so the match dialog and
// the Demo's `matchInvoice` work on what is LEFT of a payment: the
// resolution (exact, over, under) is derived from the remainder, a part may
// be named, and a part above the remainder is refused as the SQL refuses it.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/widgets/match_invoice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/refusal_matchers.dart';
import '../../helpers/screens/invoices.dart' show seededMoney;

/// A payment of 120.00 of which 70.00 is used: 50.00 is left.
final _entry = LedgerEntry(
  id: 'part',
  memberId: 'anna',
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: 12000,
  description: 'Transfer',
  period: '2026-03',
  createdAt: DateTime(2026, 3, 20),
  occurredOn: DateTime(2026, 3, 18),
);

final _left = PaymentLeft(
  entry: _entry,
  receivedCents: 12000,
  assignedCents: 7000,
  leftCents: 5000,
);

void main() {
  Future<MatchChoice?> openDialog(WidgetTester tester, int due) async {
    MatchChoice? choice;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          key: const ValueKey('open'),
          onPressed: () async => choice = await showDialog<MatchChoice>(
            context: context,
            builder: (_) => MatchInvoiceDialog(
              dueCents: due,
              currency: MoneyFormat('EUR', locale: 'en'),
              payments: [_left],
              selected: 'part',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('50.00'), findsWidgets);
    return choice;
  }

  testWidgets('a remainder equal to what is due is an exact match', (
    tester,
  ) async {
    await openDialog(tester, 5000);
    expect(find.byKey(const ValueKey('invoice-match-credit-note')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-match-confirm')), findsNothing);
  });

  testWidgets('a remainder above what is due offers the over choices', (
    tester,
  ) async {
    await openDialog(tester, 3000);
    expect(find.byKey(const ValueKey('invoice-match-credit-note')), findsOneWidget);
    expect(find.textContaining('20.00'), findsWidgets);
  });

  testWidgets('a remainder below what is due asks for a note', (tester) async {
    await openDialog(tester, 12000);
    expect(find.textContaining('70.00'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-match-confirm')), findsOneWidget);
    expect(find.text('A note is required.'), findsOneWidget);
  });

  group('the Demo matchInvoice with a part', () {
    test('a part leaves the rest free; a part above it, or the same '
        'invoice again, is refused', () async {
      final money = await seededMoney(matched: false);
      final invoice = money.invoices.single;
      final paymentId = money.seedPayment(
        invoice.memberId,
        invoice.totalCents + 10000,
      );
      final payment = money.ledger.firstWhere((e) => e.id == paymentId);

      await expectLater(
        money.matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: paymentId,
          resolution: 'exact',
          amountCents: payment.amountCents + 1,
        ),
        throwsA(isA<StateError>()),
      );
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: paymentId,
        resolution: 'exact',
        amountCents: invoice.totalCents,
      );
      expect(money.usedPaymentCents[paymentId], invoice.totalCents);
      expect(money.remainingOf(payment), 10000);
      await expectLater(
        money.matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: paymentId,
          resolution: 'exact',
        ),
        throwsRefusal('DKI06'),
        reason: 'the invoice already holds a part of this payment',
      );
    });

    test('without an amount the whole remainder is taken, then nothing is '
        'left', () async {
      final money = await seededMoney(matched: false);
      final invoice = money.invoices.single;
      final paymentId = money.seedPayment(invoice.memberId, invoice.totalCents);
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: paymentId,
        resolution: 'exact',
      );
      final payment = money.ledger.firstWhere((e) => e.id == paymentId);
      expect(money.remainingOf(payment), 0);
    });
  });
}
