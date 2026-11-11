// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Partially paid is NOT closed (#504): the invoice stays on the Open
// tab — the remainder is owed — until the outstanding amount is
// cancelled through the VALIDATION framework. Only the validated
// write-off archives it.
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoice_writeoff.dart' show partialMatch;
import '../../helpers/screens/invoices.dart' show
        openInvoice,
        pumpInvoices,
        seededMoney,
        showInvoicesByInvoice,
        showPaidInvoices;
import '../../helpers/test_clock.dart';


void main() {
  group('lifecycle (#504)', () {
    test('a standing partial match reads PARTIALLY PAID — an open state; '
        'only the write-off closes it', () {
      final invoice = Invoice(
        id: 'inv-1',
        workspaceId: 'ws-1',
        memberId: 'member-1',
        number: 'INV-1',
        issuedAt: kTestNow,
        title: '2026-07',
        lines: const [],
        totalCents: 25000,
        currency: 'EUR',
        memberName: 'Flo',
        memberAddress: '',
        workspaceName: 'Test Space',
        workspaceAddress: '',
        issuerName: 'Owner',
        signature: 'sig',
      );
      expect(invoiceLifecycleOf(invoice, partialMatch('inv-1')),
          InvoiceLifecycle.partiallyPaid);
      expect(
        invoiceLifecycleOf(
            invoice, partialMatch('inv-1', writeoffAt: kTestNow)),
        InvoiceLifecycle.remainderCancelled,
      );
    });
  });

  testWidgets(
      'a PARTIALLY PAID invoice stays OPEN with its remaining amount, '
      'matchable, never voided — not on the closed list (#504)',
      (tester) async {
    final money = await seededMoney(matched: false);
    // Give the seeded invoice a standing PARTIAL match.
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] = partialMatch(invoice.id);
    await pumpInvoices(tester, money: money);

    // #3587 — the home's open list: the line says what is still open.
    await showInvoicesByInvoice(tester);
    final row = find.byKey(ValueKey('invoicing-row-${invoice.id}'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('Partly paid')),
        findsOneWidget);
    // #506 — further payments stay matchable against the remainder;
    // voiding stays off (the invoice is matched and definitive).
    await openInvoice(tester, invoice.id);
    expect(find.byKey(const ValueKey('invoice-match-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // The closed list does NOT hold it.
    await showPaidInvoices(tester);
    expect(row, findsNothing);
  });

  testWidgets(
      'the write-off request: the dialog explains the validation, the '
      'pending chip replaces the button (#504)',
      skip: true, // #3587 gap: the home and the invoice's sheet offer no
      // write-off request; the Open card was its door (the wizard's
      // payments step still has one, behind its flag).
      (tester) async {});

  testWidgets(
      'once the write-off is VALIDATED the invoice moves to the closed list '
      'as "remainder cancelled" (#504)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id, writeoffAt: kTestNow);
    await pumpInvoices(tester, money: money);

    // #3587 — not on the open list...
    await showInvoicesByInvoice(tester);
    final row = find.byKey(ValueKey('invoicing-row-${invoice.id}'));
    expect(row, findsNothing);

    // ...but on the closed one, and its sheet says how it closed.
    await showPaidInvoices(tester);
    expect(row, findsOneWidget);
    await openInvoice(tester, invoice.id);
    expect(find.textContaining('emainder cancelled'), findsWidgets);
  });

}
