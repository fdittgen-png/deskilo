// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 (X1.B) -- the structured invoice (CII, UBL) states a commercial line's
// exact quantity with its reviewed unit code, its entered net price with the
// quantity it is quoted for, and the net the server froze; what it cannot state
// exactly it refuses (never the integer default, never `C62`).
import 'package:deskilo/core/jurisdiction/installed_invoice_rules.dart';
import 'package:deskilo/core/jurisdiction/installed_payment_slips.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/invoice_document_context_builder.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'COWORKONTI',
  street: '4 avenue de Castelnau',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '10825191900016',
);
const _buyer = InvoiceParty(
  name: 'SASU KaloA',
  company: 'SASU KaloA',
  street: '209 rue Jean Bart',
  city: 'Labège',
  postalCode: '31670',
  country: 'FR',
);

Map<String, Object?> _facts({
  String quantity = '0.75',
  String unitCode = 'KGM',
  String basis = 'net',
  String baseQuantity = '1',
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'version': 1,
  'line_id': 'L-1',
  'quantity': quantity,
  'unit': <String, Object?>{'code': 'kg', 'un_ece_code': unitCode, 'label': 'kg'},
  'unit_price': <String, Object?>{
    'amount': '12',
    'currency': 'EUR',
    'basis': basis,
    'base_quantity': baseQuantity,
  },
  'supply': 'goods',
  'tax_facts': <String, Object?>{},
  'amounts': <String, Object?>{
    'currency': 'EUR',
    'net_minor': '900',
    'tax_minor': '180',
    'gross_minor': '1080',
  },
  ...extra,
};

InvoiceLine _line([Map<String, Object?>? facts]) => invoiceLineFromSnapshot(<String, Object?>{
  'kind': 'service',
  'label': 'Beans',
  'quantity': 1,
  'amount_cents': 1080,
  'vat_percent': 20,
  'commercial': facts ?? _facts(),
});

Invoice _invoice(List<InvoiceLine> lines, {int total = 1080}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9, 6),
  title: 'T',
  lines: lines,
  totalCents: total,
  currency: 'EUR',
  memberName: 'SASU KaloA',
  memberAddress: '',
  workspaceName: 'COWORKONTI',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: _seller,
);

EInvoiceInput _input(Invoice invoice) => EInvoiceInput(
  paymentReferenceRules: installedPaymentReferenceRules,
  nationalRules: installedNationalInvoiceRules,
  invoice: invoice,
  seller: _seller,
  buyer: _buyer,
  lineText: (l) => l.label,
  reference: ActiveTaxReference.current,
);

String _text(XmlDocument d, String name) =>
    d.findAllElements(name, namespace: '*').first.innerText;

void main() {
  test('CII: the exact quantity, its unit code and the entered net price', () {
    final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice([_line()]))));
    final qty = doc.findAllElements('BilledQuantity', namespace: '*').single;
    expect([qty.innerText, qty.getAttribute('unitCode')], ['0.75', 'KGM']);
    expect(_text(doc, 'ChargeAmount'), '12.00');
    expect(_text(doc, 'LineTotalAmount'), '9.00');
    expect(doc.findAllElements('BasisQuantity', namespace: '*'), isEmpty);
  });

  test('UBL: the same facts, and a base quantity when the price is quoted for more than one', () {
    final doc = XmlDocument.parse(buildInvoiceUbl(_input(_invoice([_line()]))));
    final qty = doc.findAllElements('InvoicedQuantity', namespace: '*').single;
    expect([qty.innerText, qty.getAttribute('unitCode')], ['0.75', 'KGM']);
    expect(_text(doc, 'PriceAmount'), '12.00');
    expect(_text(doc, 'LineExtensionAmount'), '9.00');
    final quoted = XmlDocument.parse(buildInvoiceUbl(_input(_invoice([
      _line(_facts(baseQuantity: '10', extra: {
        'amounts': {'currency': 'EUR', 'net_minor': '90', 'tax_minor': '18', 'gross_minor': '108'},
      })),
    ], total: 108))));
    final base = quoted.findAllElements('BaseQuantity', namespace: '*').single;
    expect([base.innerText, base.getAttribute('unitCode')], ['10', 'KGM']);
  });

  test('the totals agree with the line: net 9.00, tax 1.80', () {
    final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice([_line()]))));
    expect(_text(doc, 'TaxBasisTotalAmount'), '9.00');
    expect(_text(doc, 'TaxTotalAmount'), '1.80');
  });

  test('what cannot be stated exactly is refused, never defaulted to C62', () {
    final blocked = <String, InvoiceLine>{
      'no UN/ECE code': _line(_facts(unitCode: '')),
      'a gross price': _line(_facts(basis: 'gross')),
      'a correction': _line(_facts(quantity: '-0.5', extra: {
        'source_ref': {'kind': 'invoice', 'id': 'INV-0', 'line_id': 'L-0'},
        'amounts': {'currency': 'EUR', 'net_minor': '-600', 'tax_minor': '-120', 'gross_minor': '-720'},
      })),
      'a future source': _line(_facts(extra: {'source_ref': {'kind': 'tender', 'id': 'T-1'}})),
      'an unknown version': _line({..._facts(), 'version': 9}),
      'an unknown supply': _line(_facts(extra: {'supply': 'digital'})),
    };
    for (final MapEntry(:key, :value) in blocked.entries) {
      final invoice = _invoice([value]);
      expect(() => buildInvoiceCii(_input(invoice)), throwsA(isA<CommercialOutputBlocked>()), reason: '$key (CII)');
      expect(() => buildInvoiceUbl(_input(invoice)), throwsA(isA<CommercialOutputBlocked>()), reason: '$key (UBL)');
    }
  });

  test('a currency that is not the invoice\'s is refused', () {
    final other = _line(_facts(extra: {
      'unit_price': {'amount': '12', 'currency': 'USD', 'basis': 'net', 'base_quantity': '1'},
      'amounts': {'currency': 'USD', 'net_minor': '900', 'tax_minor': '180', 'gross_minor': '1080'},
    }));
    expect(() => buildInvoiceCii(_input(_invoice([other]))), throwsA(isA<CommercialOutputBlocked>()));
  });

  test('the national profiles and the SAF-T book still refuse a commercial line', () {
    expect(
      () => invoiceDocumentContextOf(_input(_invoice([_line()]))),
      throwsA(isA<CommercialOutputBlocked>()),
    );
  });

  test('a legacy line is stated as before: C62 and its integer', () {
    final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice([
      const InvoiceLine(kind: 'service', label: 'Coffee', quantity: 2, amountCents: 1200, vatPercent: 20),
    ], total: 1200))));
    final qty = doc.findAllElements('BilledQuantity', namespace: '*').single;
    expect([qty.innerText, qty.getAttribute('unitCode')], ['2', 'C62']);
  });
}
