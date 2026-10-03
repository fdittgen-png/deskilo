// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NEGATIVE invoices are CREDIT NOTES the WORKSPACE pays (#508): no
// reminders, no member-payment matching — the workspace records the
// refund; the payout books against the member's balance and the avoir
// closes as Refunded.

import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart' show pumpInvoices, seededMoney;

void main() {
  testWidgets(
      'a NEGATIVE open invoice offers Record-the-refund — no reminder, '
      'no member-payment match — and closes as Refunded with the payout '
      'booked (#508)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoices[0] = invoice.copyWith(totalCents: -80000);
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('To refund'), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-refund-${invoice.id}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('invoice-remind-${invoice.id}')),
        findsNothing);
    expect(find.byKey(ValueKey('invoice-match-${invoice.id}')),
        findsNothing);

    await tester
        .tap(find.byKey(ValueKey('invoice-refund-${invoice.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('WORKSPACE owes the member'),
        findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-refund-note')),
      'bank transfer 05/08',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-refund-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Refund recorded.'), findsOneWidget);

    // The payout charge offsets the member's credit…
    final payout = money.ledger.last;
    expect(payout.kind, LedgerKind.charge);
    expect(payout.amountCents, 80000);
    expect(payout.description, contains('Refund ${invoice.number}'));
    // …and the avoir is closed.
    final match = money.invoiceMatchesStore[invoice.id]!;
    expect(match.resolution, 'refunded');

    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.text(invoice.number), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
  });

}
