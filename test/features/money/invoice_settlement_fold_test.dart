// SPDX-License-Identifier: 0BSD
//
// #831 — settled sources fold under their settlement: the settlement
// carries the sources' lines tagged with their number; the sources
// leave the open list, the archive and the member's list as peers and
// nest under it with the stamped PDF as their one affordance; the
// detail sheet of a source says so and offers reading only; the
// watermark priority; exports count the originals once.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices;

/// Two open invoices of member-1 regrouped into one.
Future<({FakeMoneyRepository money, String a, String b, String settlement})>
    _settledMoney() async {
  final money = FakeMoneyRepository();
  final a = await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-01');
  final b = await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-02');
  final settlement = await money.settleInvoices(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    invoiceIds: [a, b],
  );
  return (money: money, a: a, b: b, settlement: settlement);
}

void main() {
  test('the fake settlement carries every source line, tagged with its '
      'number, and points the sources at it', () async {
    final s = await _settledMoney();
    final settlement = s.money.invoices.firstWhere((i) => i.id == s.settlement);
    expect(settlement.kind, InvoiceKind.settlement);
    expect(settlement.lines.every((l) => l.sourceNumber.isNotEmpty), isTrue);
    expect(settlement.lines.map((l) => l.sourceNumber).toSet().length, 2);
    for (final id in [s.a, s.b]) {
      final source = s.money.invoices.firstWhere((i) => i.id == id);
      expect(source.settledByInvoiceId, s.settlement);
      expect(source.isFolded, isTrue);
    }
    expect(settledByNumberOf(
        s.money.invoices.firstWhere((i) => i.id == s.a), s.money.invoices),
        settlement.number);
  });

  test('the watermark: proforma first, then "regrouped in", then voided, '
      'then copy', () {
    InvoicePdfStrings strings({String settledIn = ''}) => InvoicePdfStrings(
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
          settledIn: settledIn,
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
        invoiceWatermark(strings(settledIn: 'Regrouped in X'),
            proforma: false, voided: false, copy: true),
        'REGROUPED IN X');
    expect(
        invoiceWatermark(strings(settledIn: 'Regrouped in X'),
            proforma: true, voided: false, copy: false),
        'PROFORMA');
    expect(invoiceWatermark(strings(), proforma: false, voided: true, copy: true),
        'ERRONEOUS');
    expect(invoiceWatermark(strings(), proforma: false, voided: false, copy: true),
        'COPY');
    expect(invoiceWatermark(strings(), proforma: false, voided: false, copy: false),
        '');
  });

  test('exports count the originals once: the VAT declaration and the '
      'accountant CSV skip the settlement document', () async {
    final s = await _settledMoney();
    final lines = computeVatDeclarationLines(
        s.money.invoices, DateTime(2020), DateTime(2040));
    final settlement = s.money.invoices.firstWhere((i) => i.id == s.settlement);
    final declared = lines.fold<int>(0, (t, l) => t + l.grossCents);
    final sources = s.money.invoices
        .where((i) => i.kind != InvoiceKind.settlement)
        .fold<int>(0, (t, i) => t + i.chargesCents);
    expect(declared, sources);
    expect(declared, isNot(sources + settlement.chargesCents));
    final csv = buildAccountantCsv(
      invoices: s.money.invoices,
      matches: const {},
      generatedAt: DateTime(2026, 9, 1),
      workspaceName: 'Test Space',
    );
    expect(csv, isNot(contains(settlement.number)));
  });

  testWidgets('the hub lists the settlement with its sources nested under '
      'it — PDF only — and no source card of its own', (tester) async {
    final s = await _settledMoney();
    await pumpInvoices(tester, money: s.money);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${s.settlement}')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-open-${s.a}')), findsNothing);
    expect(find.byKey(ValueKey('invoice-open-${s.b}')), findsNothing);
    expect(find.byKey(ValueKey('invoice-folded-${s.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-folded-pdf-${s.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-remind-${s.a}')), findsNothing);
    expect(find.byKey(ValueKey('invoice-match-${s.a}')), findsNothing);
    expect(find.textContaining('Regrouped in INV-2026-9999'), findsWidgets);
  });

  testWidgets('with the flag off the sources stay peers', (tester) async {
    final s = await _settledMoney();
    await pumpInvoices(
      tester,
      money: s.money,
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'settlementFold': false}),
    );
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${s.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-folded-${s.a}')), findsNothing);
  });

  testWidgets('the member sees the settlement with its sources under it, '
      'never the sources as invoices of their own', (tester) async {
    final s = await _settledMoney();
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(), money: s.money),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('my-invoice-${s.settlement}')), findsOneWidget);
    expect(find.byKey(ValueKey('my-invoice-${s.a}')), findsNothing);
    expect(find.byKey(ValueKey('my-invoice-folded-${s.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('my-invoice-folded-pdf-${s.a}')), findsOneWidget);
  });

  testWidgets('a source\'s detail says where it went and keeps reading and '
      'the PDF only', (tester) async {
    final s = await _settledMoney();
    final source = s.money.invoices.firstWhere((i) => i.id == s.a);
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(), money: s.money),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open'),
              onPressed: () => showInvoiceDetailSheet(
                context,
                invoice: source,
                match: null,
                canIssue: true,
                isEu: true,
                settledByNumber: 'INV-2026-9999',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-detail-folded')), findsOneWidget);
    expect(find.textContaining('Regrouped in INV-2026-9999'), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-download-${s.a}')), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-remind-${s.a}')), findsNothing);
    expect(find.byKey(ValueKey('invoice-markpaid-${s.a}')), findsNothing);
    expect(find.byKey(ValueKey('invoice-void-${s.a}')), findsNothing);
  });

  test('migration 0148 carries the full lines, the VAT aggregate and the '
      'reminder guard', () {
    final sql = File('supabase/migrations/0148_settlement_fold.sql')
        .readAsStringSync();
    for (final what in [
      "'source_number', v_src.number,",
      'by_rate as (',
      "v_vat, 'settlement', v_settles",
      "raise exception ''invoice is settled''",
      "proname = 'record_invoice_reminder'",
    ]) {
      expect(sql, contains(what), reason: what);
    }
  });
}
