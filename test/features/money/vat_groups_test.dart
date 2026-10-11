// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #947 — VAT groups: the group implies the EN 16931 category and the
// outside-base rule; a bare percentage maps to a group by the same rule
// the database back-filled; the catalogue proposes the legal groups per
// country; a not-subject line beside taxed lines is refused (BR-O-11).

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every group carries its category and base rule; the wire round-trips', () {
    expect(VatGroup.standard.category, 'S');
    expect(VatGroup.zero.category, 'Z');
    expect(VatGroup.exempt.category, 'E');
    expect(VatGroup.notSubject.category, 'O');
    expect((VatGroup.deposit.category, VatGroup.deposit.outsideBase), ('O', true));
    expect((VatGroup.excise.category, VatGroup.excise.outsideBase), ('S', false));
    for (final g in VatGroup.values) {
      expect(VatGroup.fromWire(g.wire), g);
    }
    expect(VatGroup.fromWire('lottery'), VatGroup.standard);
  });

  test('a bare percentage falls in the group the database back-fills', () {
    expect(vatGroupForPercent(20), VatGroup.standard);
    expect(vatGroupForPercent(19), VatGroup.standard);
    expect(vatGroupForPercent(10), VatGroup.intermediate);
    expect(vatGroupForPercent(7), VatGroup.reduced);
    expect(vatGroupForPercent(5.5), VatGroup.reduced);
    expect(vatGroupForPercent(2.1), VatGroup.superReduced);
    expect(vatGroupForPercent(0), VatGroup.zero);
    expect(vatGroupForPercent(0, category: 'E'), VatGroup.exempt);
    expect(vatGroupForPercent(0, category: 'O'), VatGroup.notSubject);
  });

  test('a rate carries its group through the wire, and reads as standard '
      'when an older row has none', () {
    const deposit = VatRate(label: 'Consigne', percent: 0, category: 'O', groupKey: 'deposit', outsideBase: true, exemptionReason: 'hors champ');
    final back = VatRate.fromRow({...deposit.toJson(), 'id': 'r1'});
    expect((back.group, back.outsideBase, back.exemptionReason), (VatGroup.deposit, true, 'hors champ'));
    expect(VatRate.fromRow(const {'id': 'r2', 'label': 'x', 'percent': 20}).group, VatGroup.standard);
  });

  test('the catalogue proposes the legal groups with examples: France knows '
      'press and the deposit, Germany taxes the Pfand with the goods', () {
    final fr = vatGroupExamples('FR');
    expect(fr.map((e) => e.group), containsAll([VatGroup.superReduced, VatGroup.deposit, VatGroup.excise, VatGroup.notSubject]));
    final de = vatGroupExamples('DE');
    expect(de.map((e) => e.group), isNot(contains(VatGroup.deposit)));
    expect(de.first.example, contains('Pfand'));
    expect(vatGroupExamples('XX'), isNotEmpty);
  });

  test('BR-O-11: a not-subject line beside taxed lines blocks the e-invoice; '
      'an all-O association document does not', () {
    Invoice inv(List<InvoiceVatTotal> totals) => Invoice(
          id: 'i', workspaceId: 'w', memberId: 'm', number: 'INV-1', issuedAt: DateTime(2026, 9, 6),
          period: '2026-09', title: '', lines: const [InvoiceLine(kind: 'service', label: 'x', amountCents: 1000)],
          totalCents: 1000, currency: 'EUR', memberName: 'A', memberAddress: '', workspaceName: 'W',
          workspaceAddress: '', issuerName: 'F', signature: 'f' * 64, vatTotals: totals,
        );
    const seller = InvoiceParty(name: 'W', country: 'FR', legalId: '123456789', vatId: 'FR12123456789', vatRegime: 'vat_registered');
    const buyer = InvoiceParty(name: 'B', country: 'FR');
    final mixed = checkEInvoiceReadiness(
      invoice: inv(const [InvoiceVatTotal(percent: 20, category: 'S', netCents: 800, vatCents: 160, grossCents: 960), InvoiceVatTotal(percent: 0, category: 'O', netCents: 40, vatCents: 0, grossCents: 40)]),
      seller: seller, buyer: buyer,
    );
    expect(mixed.blocking, contains(EInvoiceGap.mixedNotSubjectLines));
    final association = checkEInvoiceReadiness(
      invoice: inv(const [InvoiceVatTotal(percent: 0, category: 'O', netCents: 1000, vatCents: 0, grossCents: 1000)]),
      seller: seller.copyWith(vatRegime: 'not_subject', vatId: '', taxExemptionReason: 'art. 293 B'), buyer: buyer,
    );
    expect(association.gaps, isNot(contains(EInvoiceGap.mixedNotSubjectLines)));
  });

  test('#2356: Z and E from the seller\'s own 0 % rates reach vat_totals, '
      'and every line and subtotal of the e-invoice says the same', () {
    // The server's row (0407): a VAT-registered seller, a line at 20 %, a
    // zero-rated line and an exempt one, each with the category frozen.
    final invoice = Invoice.fromRow({
      'id': 'i', 'workspace_id': 'w', 'member_id': 'm', 'number': 'INV-2026-0001',
      'issued_at': '2026-10-01T09:00:00Z', 'period': '2026-09', 'title': '2026-09',
      'lines': [
        {'kind': 'subscription', 'label': '', 'amount_cents': 1200, 'vat_percent': 20, 'vat_category': 'S'},
        {'kind': 'adjustment', 'label': 'Export', 'amount_cents': 1000, 'vat_percent': 0, 'vat_category': 'Z'},
        {'kind': 'adjustment', 'label': 'Training', 'amount_cents': 500, 'vat_percent': 0, 'vat_category': 'E'},
      ],
      'total_cents': 2700, 'currency': 'EUR', 'member_name': 'B', 'member_address': '',
      'workspace_name': 'W', 'workspace_address': '', 'issuer_name': 'F', 'signature': 'f' * 64,
      'vat_totals': [
        {'percent': 20, 'category': 'S', 'gross_cents': 1200, 'net_cents': 1000, 'vat_cents': 200},
        {'percent': 0, 'category': 'E', 'gross_cents': 500, 'net_cents': 500, 'vat_cents': 0},
        {'percent': 0, 'category': 'Z', 'gross_cents': 1000, 'net_cents': 1000, 'vat_cents': 0},
      ],
    });
    expect(invoice.lines.map((l) => l.vatCategory), ['S', 'Z', 'E']);
    expect(invoice.vatBreakdown(zeroCategory: 'O').map((t) => t.category), ['S', 'E', 'Z']);
    const seller = InvoiceParty(name: 'W', country: 'FR', legalId: '123456789', vatId: 'FR12123456789', vatRegime: 'vat_registered', street: '1 rue', city: 'Pézenas', postalCode: '34120');
    const buyer = InvoiceParty(name: 'B', country: 'FR', street: '2 rue', city: 'Pézenas', postalCode: '34120');
    final ubl = buildInvoiceUbl(invoice: invoice, seller: seller, buyer: buyer, lineText: (l) => l.label);
    final lineIds = RegExp(r'<cac:ClassifiedTaxCategory>\s*<cbc:ID>(\w+)</cbc:ID>')
        .allMatches(ubl).map((m) => m.group(1)).toList();
    expect(lineIds, ['S', 'Z', 'E']);
    final subtotalIds = RegExp(r'<cac:TaxSubtotal>[\s\S]*?<cac:TaxCategory>\s*<cbc:ID>(\w+)</cbc:ID>')
        .allMatches(ubl).map((m) => m.group(1)).toList();
    expect(subtotalIds, ['S', 'E', 'Z']);
    final cii = buildInvoiceCii(invoice: invoice, seller: seller, buyer: buyer, lineText: (l) => l.label);
    final ciiLines = RegExp(r'<ram:IncludedSupplyChainTradeLineItem>[\s\S]*?<ram:CategoryCode>(\w+)</ram:CategoryCode>')
        .allMatches(cii).map((m) => m.group(1)).toList();
    expect(ciiLines, ['S', 'Z', 'E']);
    // A line issued before 0403 carries no category: derived as before.
    const old = InvoiceLine(label: 'x', amountCents: 100);
    expect(old.vatCategory, isEmpty);
  });

}
