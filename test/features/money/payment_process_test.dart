// SPDX-License-Identifier: 0BSD
//
// #510 — the payment process as the MEMBER reads it: once an invoice
// covers a month, the DOCUMENT decides settled/outstanding. The payment
// that clears an invoice is usually recorded in a LATER month, so the
// month's own ledger arithmetic (charges − credits of that period)
// would read "outstanding" forever on an invoiced-and-paid month.
import 'dart:io';

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
    // #812 — the stage strip: To collect carries the REMAINING sum; the
    // credit note is the issuer's move (refund), so it sits under To
    // confirm rather than inflating what members owe.
    expect(find.text('$remaining outstanding'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-stage-collect')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-stage-confirm')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  group('the account becomes REAL (#512)', () {
    test('an account credit (avoir) settles an open PAST invoice — '
        'imputation; a baked credit is refused', () async {
      final money = await seededMoney(matched: false);
      final invoice = money.invoices.single;
      // The avoir covers the invoice exactly → resolution 'exact'.
      final avoir =
          money.seedCreditNote('member-1', invoice.totalCents);
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: avoir,
        resolution: 'exact',
      );
      expect(money.invoiceMatchesStore[invoice.id]!.resolution, 'exact');

      // A credit BAKED into an issued invoice (its period covered by a
      // LATER-issued document) cannot settle a second one.
      final money2 = await seededMoney(matched: false);
      final second = await money2.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-01',
      );
      final baked = money2.seedCreditNote('member-1', 500,
          period: '2026-01'); // declared for an ALREADY-invoiced month…
      // …but seeded AFTER issuance (kTestNow == issuedAt): not baked.
      // Backdate the credit to make it genuinely baked.
      final i = money2.ledger.indexWhere((e) => e.id == baked);
      money2.ledger[i] = money2.ledger[i].copyWith(
        createdAt: kTestNow.subtract(const Duration(days: 1)),
      );
      await expectLater(
        money2.matchInvoice(
          invoiceId: second,
          paymentLedgerId: baked,
          resolution: 'under_accepted',
          note: 'trying to spend it twice',
        ),
        throwsA(isA<StateError>()),
      );
      // The un-baked shape of the same credit IS accepted.
      final fresh = money2.seedCreditNote('member-1', 500);
      await money2.matchInvoice(
        invoiceId: second,
        paymentLedgerId: fresh,
        resolution: 'under_accepted',
        note: 'partial imputation',
      );
      expect(money2.invoiceMatchesStore[second]!.paidCents, 500);
    });

    test('fetchMemberAccount: credit, open remainders, refunds, net',
        () async {
      final money = await seededMoney(matched: false);
      final invoice = money.invoices.single;
      // €50 validated instalment → remaining = total − 5000.
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: money.seedPayment('member-1', 5000),
        resolution: 'under_accepted',
        note: 'partial',
      );
      money.seedCreditNote('member-1', 30000); // avoir on account
      money.invoices.add(_invoice('cn', totalCents: -800)); // refund due

      final account = await money.fetchMemberAccount('member-1');
      final remaining = invoice.totalCents - 5000;
      expect(account.creditCents, 30000);
      expect(account.openInvoices.single.remainingCents, remaining);
      expect(account.openInvoices.single.paidCents, 5000);
      expect(account.refundsDueCents, 800);
      expect(account.netPositionCents, 30000 + 800 - remaining);
    });

    testWidgets(
        'the Money tab shows the REAL position: credit on account, the '
        'open past invoice at its remainder, and the net', (tester) async {
      final money = await seededMoney(matched: false);
      money.seedCreditNote('member-1', 30000);
      await pumpMoney(tester, money: money);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('account-card')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Credit on account'), findsOneWidget);
      // The bill's Payments & credits section lists the avoir too.
      expect(find.text('+€300.00'), findsWidgets);
      expect(find.text(money.invoices.single.number), findsOneWidget);
      expect(find.text('Net position'), findsOneWidget);
      // Credit AND open invoices coexist → the imputation hint shows.
      expect(find.textContaining('can settle open invoices'),
          findsOneWidget);
    });

    testWidgets(
        'a month fully before the membership owes NOTHING — no '
        'subscription, no Outstanding (#512)', (tester) async {
      final money = FakeMoneyRepository()
        ..memberJoinedPeriod = kTestPeriod;
      await pumpMoney(tester, money: money);

      // Browse one month back — before the membership began.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('Outstanding'), findsNothing);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('€0.00'), findsWidgets);
    });

    test('migration 0103 wires the four rules', () {
      final sql = File('supabase/migrations/0103_account_reality.sql')
          .readAsStringSync();
      // 1. pre-membership months are empty
      expect(sql, contains("joined_at at time zone v_tz, 'YYYY-MM'"));
      // 2. imputation: adjustment credits settle invoices
      expect(sql, contains("category in ('payment', 'adjustment')"));
      // 3. spend-once, both directions
      expect(sql, contains('credit already deducted on an issued invoice'));
      expect(
          sql,
          contains('not exists (\n      select 1 from public.invoice_match_payments jr\n'
              '      where jr.payment_ledger_id = le.id));'));
      // 4. the real position
      expect(sql, contains('member_account'));
      expect(sql, contains("'net_position_cents', v_credit + v_refunds - v_open_total"));
    });
  });
}
