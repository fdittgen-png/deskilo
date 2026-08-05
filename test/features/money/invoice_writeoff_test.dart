// SPDX-License-Identifier: 0BSD
//
// Partially paid is NOT closed (#504): the invoice stays on the Open
// tab — the remainder is owed — until the outstanding amount is
// cancelled through the VALIDATION framework. Only the validated
// write-off archives it.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

InvoiceMatch partialMatch(String invoiceId, {DateTime? writeoffAt}) =>
    InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: 10000,
      resolution: 'under_accepted',
      note: 'paid what they could',
      matchedAt: kTestNow,
      writeoffAt: writeoffAt,
    );

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
      'a PARTIALLY PAID invoice sits on the OPEN tab with its remaining '
      'amount and the write-off request — not in the archive (#504)',
      (tester) async {
    final money = await seededMoney(matched: false);
    // Give the seeded invoice a standing PARTIAL match.
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] = partialMatch(invoice.id);
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    // Open tab: the remaining amount + the REQUEST affordance.
    expect(find.textContaining('Remaining'), findsOneWidget);
    final writeoffButton =
        find.byKey(ValueKey('invoice-writeoff-${invoice.id}'));
    expect(writeoffButton, findsOneWidget);
    // A matched invoice offers no second match and no voiding.
    expect(find.byKey(ValueKey('invoice-match-${invoice.id}')),
        findsNothing);
    expect(find.byKey(ValueKey('invoice-void-open-${invoice.id}')),
        findsNothing);

    // The archive does NOT hold it.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.text(invoice.number), findsNothing);

    // File the write-off request: dialog explains the validation, the
    // pending chip replaces the button.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(writeoffButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('validators confirm'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-writeoff-reason')),
      'member left the association',
    );
    await tester
        .tap(find.byKey(const ValueKey('invoice-writeoff-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Write-off requested'), findsOneWidget);
    expect(
        find.byKey(
            ValueKey('invoice-writeoff-pending-${invoice.id}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('invoice-writeoff-${invoice.id}')),
        findsNothing);
  });

  testWidgets(
      'once the write-off is VALIDATED the invoice moves to the archive '
      'as "remainder cancelled" (#504)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id, writeoffAt: kTestNow);
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.text(invoice.number), findsNothing);

    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.text(invoice.number), findsOneWidget);
    expect(find.textContaining('remainder cancelled'), findsOneWidget);
  });

  test('migration 0100 wires the RPC, the event type and the confirm '
      'branch', () {
    final sql = File('supabase/migrations/0100_invoice_writeoff.sql')
        .readAsStringSync();
    expect(sql, contains('request_invoice_writeoff'));
    expect(sql, contains("'invoice_writeoff'"));
    expect(sql, contains('writeoff_at'));
    expect(sql, contains("resolution = 'under_accepted' and writeoff_at is null"));
    // The verbatim-copied service_charge branch keeps its amount.
    expect(
        sql,
        contains(
            "(v_event.payload->>'amount_cents')::int,\n        (v_event.payload->>'name')"));
  });
}
