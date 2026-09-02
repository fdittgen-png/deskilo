// SPDX-License-Identifier: 0BSD
//
// #837 — a regrouping invoice can be handed over alone, or with the
// invoices it replaced appended behind it: their own pages, after the
// new one and never overlapping it, each stamped as regrouped. The same
// choice governs the on-screen preview, and the archive keeps both
// either way, the sources reachable only from the regrouping invoice.
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import 'invoices_test.dart' show pumpInvoices;

/// Two invoices of one member, regrouped into a third.
Future<
    ({
      FakeMoneyRepository money,
      String a,
      String b,
      String settlement,
      String plain,
    })>
    _regrouped() async {
  final money = FakeMoneyRepository();
  final a = await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-01');
  final b = await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-02');
  final settlement = await money.settleInvoices(
      workspaceId: 'ws-1', memberId: 'member-1', invoiceIds: [a, b]);
  // Paid, so it is a CLOSED document: the archive is where a regrouping
  // and the invoices behind it live once the money has moved.
  final total =
      money.invoices.firstWhere((i) => i.id == settlement).totalCents;
  await money.matchInvoice(
    invoiceId: settlement,
    paymentLedgerId: money.seedPayment('member-1', total, period: '2026-01'),
    resolution: 'exact',
  );
  // An ordinary closed invoice beside it: nothing to attach, nothing to ask.
  final plain = await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-03');
  await money.matchInvoice(
    invoiceId: plain,
    paymentLedgerId: money.seedPayment(
        'member-1',
        money.invoices.firstWhere((i) => i.id == plain).totalCents,
        period: '2026-03'),
    resolution: 'exact',
  );
  return (money: money, a: a, b: b, settlement: settlement, plain: plain);
}

Future<void> _openArchiveOn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
  await tester.pumpAndSettle();
}

void main() {
  test('the regrouping invoice names the invoices it replaced, in issue '
      'order, and a plain invoice names none', () async {
    final r = await _regrouped();
    final settlement =
        r.money.invoices.firstWhere((i) => i.id == r.settlement);
    expect(settlement.settles.map((s) => s.invoiceId), [r.a, r.b]);
    expect(r.money.invoices.firstWhere((i) => i.id == r.a).settles, isEmpty);
  });

  testWidgets('downloading a regrouping invoice asks, and the answer '
      'changes the document: attaching it adds pages after the first',
      (tester) async {
    final r = await _regrouped();
    Uint8List? captured;
    await pumpInvoices(
      tester,
      money: r.money,
      saver: ({required bytes, required fileName}) async {
        captured = Uint8List.fromList(bytes);
        return 'Download/$fileName';
      },
    );
    await _openArchiveOn(tester);

    // Alone first.
    await tester.tap(
        find.byKey(ValueKey('invoice-download-row-${r.settlement}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-annex-with')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-annex-alone')));
    await tester.pumpAndSettle();
    final alone = captured!.length;
    expect(alone, greaterThan(0));

    // Then with the regrouped invoices attached.
    captured = null;
    await tester.tap(
        find.byKey(ValueKey('invoice-download-row-${r.settlement}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-annex-with')));
    await tester.pumpAndSettle();
    final withAnnexes = captured!.length;

    expect(withAnnexes, greaterThan(alone),
        reason: 'the two regrouped invoices must add pages of their own');
  });

  testWidgets('a plain invoice is never asked the question', (tester) async {
    final r = await _regrouped();
    Uint8List? captured;
    await pumpInvoices(
      tester,
      money: r.money,
      saver: ({required bytes, required fileName}) async {
        captured = Uint8List.fromList(bytes);
        return 'Download/$fileName';
      },
    );
    await _openArchiveOn(tester);
    await tester.tap(find.byKey(ValueKey('invoice-download-row-${r.plain}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-annex-with')), findsNothing);
    expect(captured, isNotNull);
  });

  testWidgets('the archive keeps the regrouping invoice AND the invoices '
      'behind it, nested under it', (tester) async {
    final r = await _regrouped();
    await pumpInvoices(tester, money: r.money);
    await _openArchiveOn(tester);
    expect(find.byKey(ValueKey('invoice-${r.settlement}')), findsOneWidget);
    // Not as rows of their own...
    expect(find.byKey(ValueKey('invoice-${r.a}')), findsNothing);
    // ...but as documentation under it, with the PDF as the one thing left.
    expect(find.byKey(ValueKey('archive-folded-${r.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('archive-folded-${r.b}')), findsOneWidget);
    expect(
        find.byKey(ValueKey('archive-folded-pdf-${r.a}')), findsOneWidget);
  });

  test('the annex stamp is the regrouping number, and the watermark '
      'helper prefers it over a copy stamp', () {
    const strings = InvoicePdfStrings(
      invoiceTitle: '',
      issuedOn: '',
      issuedBy: '',
      billedTo: '',
      total: '',
      signature: '',
      voided: '',
      voidedWatermark: 'Erroneous',
      proforma: 'Proforma',
      copy: 'Copy',
      settledIn: 'Regrouped in INV-2026-9999',
      replaces: '',
      description: '',
      charges: '',
      payments: '',
      annex: '',
      attendance: '',
      activity: '',
      reserved: '',
      page: '',
    );
    expect(
        invoiceWatermark(strings,
            proforma: false, voided: false, copy: true),
        'REGROUPED IN INV-2026-9999');
  });
}
