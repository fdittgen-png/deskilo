// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2440 — the exemption reason of the seller's own exempt rate, per VAT
// category (BT-120), and the Spanish correction reason (RD 1619/2012
// art. 15, R1-R5) printed on the correcting invoice.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _reason = 'Formation professionnelle (art. 261 CGI)';

const _seller = InvoiceParty(
  name: 'Test Space',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

Invoice _invoice({String reason = _reason}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-2026-0001',
  issuedAt: DateTime(2026, 7, 26),
  period: '2026-07',
  title: '2026-07',
  lines: const [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: 12000,
      vatPercent: 20,
    ),
    InvoiceLine(
      kind: 'adjustment',
      label: 'Training',
      amountCents: 5000,
    ),
  ],
  vatTotals: [
    const InvoiceVatTotal(
      percent: 20,
      category: 'S',
      grossCents: 12000,
      netCents: 10000,
      vatCents: 2000,
    ),
    InvoiceVatTotal(
      percent: 0,
      category: 'E',
      grossCents: 5000,
      netCents: 5000,
      vatCents: 0,
      exemptionReason: reason,
    ),
  ],
  totalCents: 17000,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '1 Rue Test\n34120 Pézenas',
  workspaceName: 'Test Space',
  workspaceAddress: '2 Place du Marché',
  issuerName: 'Flo',
  signature: 'f' * 64,
);

void main() {
  test('the frozen total reads its own reason back; older ones have none', () {
    expect(
      InvoiceVatTotal.fromJson(const {
        'percent': 0,
        'category': 'E',
        'exemption_reason': _reason,
      }).exemptionReason,
      _reason,
    );
    expect(
      InvoiceVatTotal.fromJson(const {'percent': 20, 'category': 'S'})
          .exemptionReason,
      '',
    );
  });

  test(
    'UBL: the E subtotal states the rate\'s reason, the S subtotal none',
    () {
      final doc = XmlDocument.parse(
        buildInvoiceUbl(
          invoice: _invoice(),
          seller: _seller,
          buyer: _buyer,
          lineText: (line) => invoiceLineText(const ReportStrings(), line),
        ),
      );
      final categories = doc
          .findAllElements('cac:TaxSubtotal')
          .map((s) => s.findAllElements('cac:TaxCategory').single)
          .toList();
      final e = categories.singleWhere(
        (c) => c.findElements('cbc:ID').single.innerText == 'E',
      );
      final s = categories.singleWhere(
        (c) => c.findElements('cbc:ID').single.innerText == 'S',
      );
      expect(
        e.findElements('cbc:TaxExemptionReason').single.innerText,
        _reason,
      );
      expect(s.findElements('cbc:TaxExemptionReason'), isEmpty);
    },
  );

  test('CII: the same reason on the E trade tax (BT-120)', () {
    final xml = buildInvoiceCii(
      invoice: _invoice(),
      seller: _seller,
      buyer: _buyer,
      lineText: (line) => invoiceLineText(const ReportStrings(), line),
    );
    expect(RegExp(RegExp.escape(_reason)).allMatches(xml), hasLength(1));
    expect(
      xml,
      contains('<ram:ExemptionReason>$_reason</ram:ExemptionReason>'),
    );
  });

  test(
    'Spain: the correcting invoice names R1-R5, and nothing for a bad code',
    () {
      List<String> mention(String code) => nationalInvoiceMentions(
        sellerCountry: 'ES',
        regime: VatRegime.vatRegistered,
        currency: 'EUR',
        untaxedCents: 0,
        correction: true,
        rectifies: 'F-2026-0007',
        correctionReason: code,
      );
      expect(
        mention('r3').single,
        contains('Motivo: R3, créditos incobrables'),
      );
      expect(mention('R1').single, contains('art. 80 uno, dos y seis'));
      expect(mention('R9').single, endsWith('F-2026-0007.'));
      expect(spanishCorrectionReasonCodes, ['R1', 'R2', 'R3', 'R4', 'R5']);
      for (final code in spanishCorrectionReasonCodes) {
        expect(mention(code).single, contains('Motivo: $code,'));
      }
    },
  );

  test('the printed exemption mention is the rate\'s reason, once per '
      'distinct reason', () {
    final data = legalMentionData(
      const ReportStrings(),
      null,
      seller: _seller,
      rateExemptionReasons: const [_reason, 'Art. 262 CGI'],
    );
    expect(data['exemption_reason'], '$_reason\nArt. 262 CGI');
  });
}
