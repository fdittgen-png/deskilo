// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1919 A — the UBL states what each line IS. A negative document is a
// UBL CreditNote (its own root, 381, CreditNoteLines, amounts stated as
// credited), not an Invoice with a fictitious prepayment. On an invoice,
// a negative line that names a VAT rate reverses a supply (a negative
// line, with its VAT), and only a line with no rate is money already
// received (PrepaidAmount). Expected figures are worked out by hand
// below, not read back from the generator.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'pezenas1',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

Invoice _doc(List<InvoiceLine> lines, {String replacesNumber = ''}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'AV-2026-0001',
  issuedAt: DateTime(2026, 7, 26),
  period: '2026-07',
  title: '2026-07',
  lines: lines,
  totalCents: lines.fold(0, (s, l) => s + l.amountCents),
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '1 Rue Test',
  workspaceName: 'pezenas1',
  workspaceAddress: '2 Place du Marché',
  issuerName: 'Flo',
  signature: 'f' * 64,
  replacesNumber: replacesNumber,
);

XmlDocument _ubl(Invoice invoice) => XmlDocument.parse(
  buildInvoiceUbl(
    invoice: invoice,
    seller: _seller,
    buyer: _buyer,
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
  ),
);

String _total(XmlDocument d, String name) =>
    d
        .findAllElements('cac:LegalMonetaryTotal')
        .single
        .findElements('cbc:$name')
        .map((e) => e.innerText)
        .firstOrNull ??
    '';

void main() {
  test('credit 120 @20 % against an invoice of 120: a CreditNote of 120', () {
    final d = _ubl(
      _doc(const [
        InvoiceLine(
          kind: 'credit',
          label: 'Avoir',
          amountCents: -12000,
          vatPercent: 20,
        ),
      ], replacesNumber: 'INV-2026-0007'),
    );
    expect(d.rootElement.name.local, 'CreditNote');
    expect(
      d.rootElement.getAttribute('xmlns'),
      'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
    );
    expect(d.findAllElements('cbc:CreditNoteTypeCode').single.innerText, '381');
    expect(d.findAllElements('cbc:InvoiceTypeCode'), isEmpty);
    final lines = d.findAllElements('cac:CreditNoteLine').toList();
    expect(lines, hasLength(1));
    expect(
      lines.single.findElements('cbc:CreditedQuantity').single.innerText,
      '1',
    );
    expect(
      lines.single.findElements('cbc:LineExtensionAmount').single.innerText,
      '100.00',
    );
    // 120 gross at 20 %: 100.00 net, 20.00 VAT, all stated as credited.
    expect(_total(d, 'LineExtensionAmount'), '100.00');
    expect(_total(d, 'TaxExclusiveAmount'), '100.00');
    expect(_total(d, 'TaxInclusiveAmount'), '120.00');
    expect(_total(d, 'PayableAmount'), '120.00');
    expect(_total(d, 'PrepaidAmount'), '', reason: 'no fictitious prepayment');
    expect(
      d
          .findAllElements('cac:TaxTotal')
          .single
          .findElements('cbc:TaxAmount')
          .single
          .innerText,
      '20.00',
    );
    expect(
      d
          .findAllElements('cac:InvoiceDocumentReference')
          .single
          .findElements('cbc:ID')
          .single
          .innerText,
      'INV-2026-0007',
    );
  });

  test('partial credit 30 @20 %: 25.00 net, 5.00 VAT, 30.00 payable', () {
    final d = _ubl(
      _doc(const [
        InvoiceLine(
          kind: 'credit',
          label: 'Avoir',
          amountCents: -3000,
          vatPercent: 20,
        ),
      ]),
    );
    expect(d.rootElement.name.local, 'CreditNote');
    expect(_total(d, 'TaxExclusiveAmount'), '25.00');
    expect(_total(d, 'TaxInclusiveAmount'), '30.00');
    expect(_total(d, 'PayableAmount'), '30.00');
  });

  test('an invoice with an advance, a discount and a charge states three '
      'different economics', () {
    // charge 120 @20 % (100 + 20), discount 12 @20 % reversed (10 + 2),
    // advance payment 50 with no rate: money already received.
    final d = _ubl(
      _doc(const [
        InvoiceLine(
          kind: 'subscription',
          label: '50',
          amountCents: 12000,
          vatPercent: 20,
        ),
        InvoiceLine(
          kind: 'credit',
          label: 'Remise',
          amountCents: -1200,
          vatPercent: 20,
        ),
        InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -5000),
      ]),
    );
    expect(d.rootElement.name.local, 'Invoice');
    final nets = d
        .findAllElements('cac:InvoiceLine')
        .map((l) => l.findElements('cbc:LineExtensionAmount').single.innerText)
        .toList();
    expect(nets, [
      '100.00',
      '-10.00',
    ], reason: 'the discount is a negative line');
    final discount = d.findAllElements('cac:InvoiceLine').last;
    expect(
      discount.findElements('cbc:InvoicedQuantity').single.innerText,
      '-1',
    );
    expect(
      discount.findAllElements('cbc:PriceAmount').single.innerText,
      '10.00',
      reason: 'BR-27: the item price is never negative',
    );
    expect(_total(d, 'LineExtensionAmount'), '90.00');
    expect(_total(d, 'TaxExclusiveAmount'), '90.00');
    expect(_total(d, 'TaxInclusiveAmount'), '108.00');
    expect(_total(d, 'PrepaidAmount'), '50.00');
    expect(_total(d, 'PayableAmount'), '58.00');
  });

  test('readiness: a pure avoir is a document to send; one that nets '
      'payments is refused', () {
    EInvoiceReadiness check(List<InvoiceLine> lines) => checkEInvoiceReadiness(
      invoice: _doc(lines),
      seller: _seller,
      buyer: _buyer,
    );
    expect(
      check(const [
        InvoiceLine(
          kind: 'credit',
          label: 'Avoir',
          amountCents: -3000,
          vatPercent: 20,
        ),
      ]).blocking,
      isNot(contains(EInvoiceGap.noChargeLines)),
    );
    final mixed = check(const [
      InvoiceLine(
        kind: 'credit',
        label: 'Avoir',
        amountCents: -3000,
        vatPercent: 20,
      ),
      InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -1000),
    ]);
    expect(mixed.blocking, contains(EInvoiceGap.creditNoteWithPayments));
    expect(
      () => _ubl(
        _doc(const [
          InvoiceLine(
            kind: 'credit',
            label: 'Avoir',
            amountCents: -3000,
            vatPercent: 20,
          ),
          InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -1000),
        ]),
      ),
      throwsArgumentError,
      reason: 'the generator never mis-states it either',
    );
  });
}
