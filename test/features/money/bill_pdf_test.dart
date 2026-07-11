// SPDX-License-Identifier: MIT
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/bill_pdf.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _period = '2026-07';

const _statement = Statement(
  period: _period,
  subscriptionPct: 50,
  feeCents: 15000,
  includedHalfDays: 22,
  openDays: 22,
  usedHalfDays: 24,
  extraHalfDays: 2,
  overageCents: 1400,
  creditsCents: 15000,
  balanceCents: -1700,
);

const _strings = BillPdfStrings(
  title: 'Monthly bill',
  subscription: 'Subscription 50%',
  entitlement: '24 of 22 half-days used (22 open days)',
  overage: '2 extra half-days',
  accessorySupplements: 'Accessory supplements',
  services: 'Consumed services',
  servicesTotal: 'Services total',
  serviceFallback: 'Service',
  openPositions: 'Open positions',
  pendingBadge: 'pending validation',
  paymentsCredits: 'Payments & credits',
  paymentFallback: 'Payment',
  expenseFallback: 'Expense reimbursement',
  adjustmentFallback: 'Adjustment',
  eventPayment: 'Payment',
  eventExpense: 'Expense',
  eventAdjustment: 'Adjustment',
  balance: 'Balance',
  settled: 'Settled',
  outstanding: 'Outstanding',
);

Uint8List _fontBytes(String path) => File(path).readAsBytesSync();

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(_fontBytes(path)));

LedgerEntry _service(String id, String description, int amountCents) =>
    LedgerEntry(
      id: id,
      memberId: 'member-1',
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: amountCents,
      description: description,
      period: _period,
      createdAt: DateTime.utc(2026, 7, 3),
    );

BillSections _sections({int serviceCount = 1}) => buildBillSections(
      period: _period,
      memberId: 'member-1',
      nowPeriod: _period,
      ledger: [
        for (var i = 0; i < serviceCount; i++)
          _service('l-service-$i', 'Coffee lot $i ×2', 300 + i),
        LedgerEntry(
          id: 'l-payment',
          memberId: 'member-1',
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: 15000,
          description: 'Bank transfer',
          period: _period,
          createdAt: DateTime.utc(2026, 7, 5),
        ),
      ],
      pendingEvents: [
        WorkspaceEvent(
          id: 'evt-pending',
          workspaceId: 'ws-1',
          type: EventType.serviceCharge,
          action: EventAction.submitted,
          actorMemberId: 'member-1',
          subjectMemberId: 'member-1',
          payload: const {
            'name': 'Printing',
            'quantity': 4,
            'amount_cents': 80,
            'period': _period,
          },
          status: EventStatus.pending,
          createdAt: DateTime.utc(2026, 7, 6),
        ),
      ],
    );

Future<Uint8List> _build({
  int serviceCount = 1,
  int accessorySupplementCents = 0,
  String? locale,
}) =>
    buildBillPdf(
      statement: _statement.copyWith(
        accessorySupplementCents: accessorySupplementCents,
      ),
      sections: _sections(serviceCount: serviceCount),
      currencyCode: 'EUR',
      workspaceName: 'Test Space',
      memberName: 'Flo',
      periodLabel: 'July 2026',
      strings: _strings,
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      locale: locale,
    );

void main() {
  test('the embedded Roboto fonts cover € (U+20AC) and − (U+2212)', () {
    // The base-14 PDF fonts cannot encode these — the whole reason the
    // fonts are embedded (#133). Guard the asset against regressions.
    for (final path in [
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Bold.ttf',
    ]) {
      final parser = TtfParser(ByteData.sublistView(_fontBytes(path)));
      expect(parser.charToGlyphIndexMap[0x20AC], isNotNull,
          reason: '$path lacks the euro sign');
      expect(parser.charToGlyphIndexMap[0x2212], isNotNull,
          reason: '$path lacks the minus sign');
    }
  });

  test('buildBillPdf renders a non-empty PDF with all sections', () async {
    final bytes = await _build();

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('more service entries grow the document', () async {
    final small = await _build(serviceCount: 1);
    final large = await _build(serviceCount: 12);

    expect(large.length, greaterThan(small.length));
  });

  test('a non-zero accessory supplement adds its line (#170)', () async {
    // Zero supplement renders no line — same guard as the on-screen bill;
    // the extra line makes the document strictly larger.
    final without = await _build();
    final withSupplement = await _build(accessorySupplementCents: 900);

    expect(withSupplement.length, greaterThan(without.length));
    expect(String.fromCharCodes(withSupplement.sublist(0, 5)), '%PDF-');
  });

  test('buildBillPdf works in all five launch locales', () async {
    await initializeDateFormatting();
    for (final locale in ['en', 'de', 'fr', 'es', 'it']) {
      final bytes = await _build(locale: locale);
      expect(bytes, isNotEmpty, reason: 'empty PDF for $locale');
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-',
          reason: 'bad header for $locale');
    }
  });
}
