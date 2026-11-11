// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Partially paid is NOT closed (#504): the invoice stays on the Open
// tab — the remainder is owed — until the outstanding amount is
// cancelled through the VALIDATION framework. Only the validated
// write-off archives it.
import 'package:deskilo/core/ui/kit/kit_action_button.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoice_writeoff.dart' show partialMatch;
import '../../helpers/screens/invoices.dart' show
        closeInvoicePage,
        invoicePageMore,
        openInvoice,
        openInvoicePageMore,
        pumpInvoices,
        registeredPayment,
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
    // Cancelling and replacing stay off (the invoice is matched and
    // definitive); the page's More offers the write-off (#3587 R1-d).
    await openInvoice(tester, invoice.id);
    await openInvoicePageMore(tester);
    expect(find.byKey(const ValueKey('invoice-more-writeoff')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-more-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-more-replace')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await closeInvoicePage(tester);

    // The closed list does NOT hold it.
    await showPaidInvoices(tester);
    expect(row, findsNothing);
  });

  testWidgets(
      'a further payment registered on a PARTIALLY PAID invoice is matched '
      'from its page (#506)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] = partialMatch(invoice.id);
    await pumpInvoices(
      tester,
      money: money,
      events: registeredPayment('member-1', 5000),
    );

    // #3587 R1-d — the page's bottom bar matches it against the remainder.
    await openInvoice(tester, invoice.id);
    expect(find.text('A payment is on the account: match it'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('invoice-page-match'))),
      isA<KitActionButton>(),
    );
  });

  testWidgets(
      'the write-off request: the dialog explains the validation and the '
      'request is filed (#504)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] = partialMatch(invoice.id);
    await pumpInvoices(tester, money: money);

    // #3587 R1-d — the invoice page's More → Write off the rest.
    await openInvoice(tester, invoice.id);
    await invoicePageMore(tester, 'invoice-more-writeoff');
    expect(find.textContaining('validators confirm'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-writeoff-reason')),
      'member left the association',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-writeoff-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Write-off requested'), findsOneWidget);
  });

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

    // ...but on the closed one, and its page says it is closed: cancelled,
    // nothing left to chase (#3587 R1-d).
    await showPaidInvoices(tester);
    expect(row, findsOneWidget);
    await openInvoice(tester, invoice.id);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-page-summary')),
        matching: find.text('Cancelled'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invoice-page-match')), findsNothing);
  });

}
