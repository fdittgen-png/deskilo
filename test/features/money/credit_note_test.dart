// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NEGATIVE invoices are CREDIT NOTES the WORKSPACE pays (#508): no
// reminders, no member-payment matching — the workspace records the
// refund; the payout books against the member's balance and the avoir
// closes as Refunded.

import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart' show invoicingRow, openInvoice, pumpInvoices, seededMoney;

void main() {
  testWidgets(
      'a NEGATIVE open invoice offers Record-the-refund — no reminder, '
      'no member-payment match — and closes as Refunded with the payout '
      'booked (#508)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoices[0] = invoice.copyWith(totalCents: -80000);
    await pumpInvoices(tester, money: money);

    // #3587 — the home's To do names the refund to pay out; the credit
    // note's sheet offers no reminder and no member-payment match.
    final refund = find.byKey(const ValueKey('invoicing-todo-payOutRefunds'));
    expect(refund, findsOneWidget);
    await openInvoice(tester, invoice.id);
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-match-action')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.ensureVisible(refund);
    await tester.tap(refund);
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

    // #3587 — the refunded credit note is on the Paid and closed list.
    final row = await invoicingRow(tester, invoice.id);
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Refunded')),
        findsOneWidget);
  });

}
