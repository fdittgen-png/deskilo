// SPDX-License-Identifier: 0BSD
//
// #510 — the payment process as the MEMBER reads it: once an invoice
// covers a month, the DOCUMENT decides settled/outstanding. The payment
// that clears an invoice is usually recorded in a LATER month, so the
// month's own ledger arithmetic (charges − credits of that period)
// would read "outstanding" forever on an invoiced-and-paid month.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/test_clock.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;
import 'money_screen_test.dart' show pumpMoney, workspaceWithInstructions;

Invoice _invoice(
  String id, {
  int totalCents = 7050,
  String? period,
  String? replaces,
  DateTime? issuedAt,
  bool voided = false,
  String memberId = 'member-1',
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: memberId,
      number: 'INV-$id',
      issuedAt: issuedAt ?? kTestNow,
      title: period ?? kTestPeriod,
      period: period ?? kTestPeriod,
      lines: const [],
      totalCents: totalCents,
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'Test Space',
      workspaceAddress: '',
      issuerName: 'Owner',
      signature: 'sig',
      voidedAt: voided ? kTestNow : null,
      replacesInvoiceId: replaces,
    );

InvoiceMatch _match(
  String invoiceId, {
  int paidCents = 7050,
  String resolution = 'exact',
  String status = 'confirmed',
  DateTime? writeoffAt,
}) =>
    InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: paidCents,
      resolution: resolution,
      status: status,
      matchedAt: kTestNow,
      writeoffAt: writeoffAt,
    );

void main() {
  group('settlementOfPeriod (#510)', () {
    test('no covering invoice → null (the ledger balance stays '
        'authoritative)', () {
      expect(settlementOfPeriod(kTestPeriod, 'member-1', const [], const {}),
          isNull);
      // Another period's invoice does not cover this one.
      expect(
        settlementOfPeriod(kTestPeriod, 'member-1',
            [_invoice('a', period: '2025-01')], const {}),
        isNull,
      );
      // Another MEMBER's invoice never covers my month — admins hold
      // the whole archive in scope.
      expect(
        settlementOfPeriod(
            kTestPeriod, 'member-1', [_invoice('a', memberId: 'other')],
            const {}),
        isNull,
      );
    });

    test('voided and replaced documents do not count; the latest '
        'covering invoice wins', () {
      final old = _invoice('old', issuedAt: DateTime(2026, 5, 1));
      final replacement =
          _invoice('new', replaces: 'old', issuedAt: DateTime(2026, 5, 2));
      final s = settlementOfPeriod(
          kTestPeriod, 'member-1', [old, replacement], const {});
      expect(s!.invoice.id, 'new');
      expect(
        settlementOfPeriod(
            kTestPeriod, 'member-1', [_invoice('v', voided: true)], const {}),
        isNull,
      );
    });

    test('remaining: full face value while open or awaiting validation, '
        'the remainder while partially paid, zero once closed', () {
      final invoice = _invoice('i');
      int remaining(InvoiceMatch? m) => settlementOfPeriod(
              kTestPeriod, 'member-1', [invoice], {'i': ?m})!
          .remainingCents;
      expect(remaining(null), 7050);
      expect(remaining(_match('i', status: 'pending')), 7050);
      expect(
          remaining(_match('i', paidCents: 5000, resolution: 'under_accepted')),
          2050);
      expect(remaining(_match('i')), 0);
      expect(
        remaining(_match('i',
            paidCents: 5000,
            resolution: 'under_accepted',
            writeoffAt: kTestNow)),
        0,
      );
    });

    test('an open credit note (#508) reads as a NEGATIVE remainder — '
        'the workspace owes; refunded closes it', () {
      final note = _invoice('c', totalCents: -800);
      expect(
        settlementOfPeriod(kTestPeriod, 'member-1', [note], const {})!
            .remainingCents,
        -800,
      );
      expect(
        settlementOfPeriod(kTestPeriod, 'member-1', [note],
                {'c': _match('c', paidCents: 800, resolution: 'refunded')})!
            .remainingCents,
        0,
      );
    });
  });

  testWidgets(
      'an invoiced-and-PAID month reads Settled on the Money tab even '
      'though its own ledger balance is negative — and how-to-pay '
      'disappears (#510)', (tester) async {
    // seededMoney: current-month invoice, matched exact against a
    // registered payment. The fake statement still says balance −1600.
    final money = await seededMoney();
    await pumpMoney(tester,
        money: money, workspace: workspaceWithInstructions());

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bill-invoice-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Invoice INV-'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Outstanding'), findsNothing);
    // The invoice remainder — not the raw ledger deficit — is the
    // balance, so nothing is owed and the how-to-pay card is gone.
    expect(find.text('How to pay'), findsNothing);
  });

  testWidgets(
      'a PARTIALLY PAID month stays outstanding at its REMAINDER, not '
      'its ledger balance (#510)', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    await money.matchInvoice(
      invoiceId: invoice.id,
      paymentLedgerId: money.seedPayment('member-1', 5000),
      resolution: 'under_accepted',
      note: 'paid what they could',
    );
    // The quorum confirmed the partial instalment.
    money.invoiceMatchesStore[invoice.id] =
        money.invoiceMatchesStore[invoice.id]!.copyWith(status: 'confirmed');
    await pumpMoney(tester, money: money);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bill-invoice-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Partially paid'), findsOneWidget);
    expect(find.text('Remaining to pay'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    final remaining = invoice.totalCents - 5000;
    // The footer shows the remainder as the (negative) balance.
    expect(
      find.text('-€${(remaining / 100).toStringAsFixed(2)}'),
      findsWidgets,
    );
  });

  testWidgets(
      'an open credit note (#508) reads "the workspace owes you" and the '
      'month is NOT outstanding for the member', (tester) async {
    final money = FakeMoneyRepository();
    money.invoices.add(_invoice('cn', totalCents: -800));
    await pumpMoney(tester, money: money);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bill-invoice-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Credit note'), findsOneWidget);
    expect(find.textContaining('owes you'), findsOneWidget);
    expect(find.text('Outstanding'), findsNothing);
    // Money the workspace owes back renders as a POSITIVE balance.
    expect(find.text('€8.00'), findsWidgets);
  });

  testWidgets(
      'the hub summary strip splits the two DIRECTIONS: to collect at '
      'the REMAINING value, to refund for open credit notes (#510)',
      (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    // €50 instalment confirmed → the strip must count the REMAINDER.
    await money.matchInvoice(
      invoiceId: invoice.id,
      paymentLedgerId: money.seedPayment('member-1', 5000),
      resolution: 'under_accepted',
      note: 'paid what they could',
    );
    money.invoices.add(_invoice('cn', totalCents: -800));
    await pumpInvoices(tester, money: money);

    final remaining =
        '€${((invoice.totalCents - 5000) / 100).toStringAsFixed(2)}';
    expect(
      find.text('1 open · $remaining outstanding'),
      findsOneWidget,
    );
    expect(find.text('1 to refund · €8.00'), findsOneWidget);
  });
}
