// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2380): an e-invoice states BT-83, the reference the payer quotes
// with the transfer, for the account it names (BT-84): the ISO 11649 creditor
// reference for an ordinary IBAN; for a Swiss QR-IBAN only the QRR frozen at
// issue (0677), never the one derived from the number's digits, and without a
// frozen one the export is refused; none for a credit note — in UBL as `cac:PaymentMeans/cbc:PaymentID` before the
// payee account, in CII as `ram:PaymentReference` before the invoice currency.
// The expected references are stated by hand from the standards.
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _iban = 'FR76 3000 6000 0112 3456 7890 189';
// A QR-IBAN of the Swiss implementation guidelines' examples (IID 31999).
const _qrIban = 'CH44 3199 9123 0008 8901 2';

// Two QRRs as 0677 freezes them (1, a sequence value, the check digit),
// checked by hand with the recursive modulus 10.
const _frozenF = '100000000000000000000000416';
const _frozenU = '100000000000000000000000424';

Invoice _invoice({
  String number = 'INV-2026-0001',
  int cents = 12000,
  String? frozenQrr,
}) =>
    Invoice(
      legalSnapshot: frozenQrr == null ? null : {'qrr': frozenQrr},
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: number,
      issuedAt: DateTime(2026, 7, 26),
      period: '2026-07',
      title: '2026-07',
      lines: [
        InvoiceLine(
          kind: cents < 0 ? 'credit' : 'subscription',
          label: cents < 0 ? 'Avoir' : '50',
          amountCents: cents,
          vatPercent: cents < 0 ? 20 : 0,
        ),
      ],
      replacesNumber: cents < 0 ? 'INV-2026-0001' : '',
      totalCents: cents,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
    );

EInvoiceInput _input(Invoice invoice, String iban) => EInvoiceInput(
  invoice: invoice,
  seller: const InvoiceParty(
    name: 'Test Space',
    street: '2 Place du Marché',
    city: 'Pézenas',
    postalCode: '34120',
    country: 'FR',
    legalId: '812345678',
    taxExemptionReason: 'Services outside the scope of VAT',
  ),
  buyer: const InvoiceParty(
    name: 'Ana Martin',
    street: '1 Rue Test',
    city: 'Pézenas',
    postalCode: '34120',
    country: 'FR',
  ),
  iban: iban,
  lineText: (line) => invoiceLineText(const ReportStrings(), line),
);

List<String> _children(XmlDocument doc, String parent) => [
  for (final e in doc.findAllElements(parent).single.childElements) e.name.qualified,
];

void main() {
  group('the reference for an account', () {
    test('an ordinary IBAN: the ISO 11649 creditor reference of the number', () {
      // "INV20260001RF00", letters as A = 10 … Z = 35, is 82 modulo 97:
      // the check digits are 98 − 82 = 16.
      final r = paymentReferenceFor(
        account: _iban,
        invoiceNumber: 'INV-2026-0001',
        creditNote: false,
      );
      expect(r, 'RF16INV20260001');
      expect(isValidScor(r), isTrue);
    });

    test('a QR-IBAN: only the QRR frozen at issue, never the derived one', () {
      expect(
        paymentReferenceFor(
          account: _qrIban,
          invoiceNumber: 'F-2026-0402',
          creditNote: false,
          legalSnapshot: const {'qrr': _frozenF},
        ),
        _frozenF,
      );
      // No frozen reference (or a malformed one): nothing is published.
      for (final snapshot in [null, const {'qrr': '123'}]) {
        expect(
          paymentReferenceFor(
            account: _qrIban,
            invoiceNumber: 'F-2026-0402',
            creditNote: false,
            legalSnapshot: snapshot,
          ),
          '',
        );
      }
      expect(isValidQrr(_frozenF) && isValidQrr(_frozenU), isTrue);
    });

    test('a credit note asks for no payment, and no account takes none', () {
      expect(
        paymentReferenceFor(account: _iban, invoiceNumber: 'AV-1', creditNote: true),
        '',
      );
      expect(
        paymentReferenceFor(account: '', invoiceNumber: 'INV-1', creditNote: false),
        '',
      );
    });
  });

  group('UBL', () {
    test('PaymentID comes after the means code and before the payee account', () {
      final doc = XmlDocument.parse(buildInvoiceUbl(_input(_invoice(), _iban)));
      expect(doc.findAllElements('cbc:PaymentID').single.innerText, 'RF16INV20260001');
      expect(_children(doc, 'cac:PaymentMeans'), [
        'cbc:PaymentMeansCode',
        'cbc:PaymentID',
        'cac:PayeeFinancialAccount',
      ]);
    });

    test('no account, no reference', () {
      final doc = XmlDocument.parse(buildInvoiceUbl(_input(_invoice(), '')));
      expect(doc.findAllElements('cbc:PaymentID'), isEmpty);
    });

    test('a credit note states no reference', () {
      final doc = XmlDocument.parse(
        buildInvoiceUbl(_input(_invoice(number: 'AV-2026-0001', cents: -12000), _iban)),
      );
      expect(doc.findAllElements('cbc:PaymentID'), isEmpty);
    });
  });

  group('CII', () {
    test('PaymentReference opens the header settlement, before the currency', () {
      final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice(), _iban)));
      final settlement = _children(doc, 'ram:ApplicableHeaderTradeSettlement');
      expect(settlement.take(2), ['ram:PaymentReference', 'ram:InvoiceCurrencyCode']);
      expect(doc.findAllElements('ram:PaymentReference').single.innerText,
          'RF16INV20260001');
    });

    test('a QR-IBAN account: the frozen QRR', () {
      final doc = XmlDocument.parse(
        buildInvoiceCii(_input(_invoice(frozenQrr: _frozenF), _qrIban)),
      );
      expect(doc.findAllElements('ram:PaymentReference').single.innerText, _frozenF);
    });

    test('no account or a credit note: no reference', () {
      expect(
        XmlDocument.parse(buildInvoiceCii(_input(_invoice(), '')))
            .findAllElements('ram:PaymentReference'),
        isEmpty,
      );
      expect(
        XmlDocument.parse(buildInvoiceCii(
          _input(_invoice(number: 'AV-2026-0001', cents: -12000), _iban),
        )).findAllElements('ram:PaymentReference'),
        isEmpty,
      );
    });
  });

  group('a QR-IBAN invoice with no frozen reference is refused, never sent '
      'without one', () {
    test('the readiness check refuses it, with its own reason', () {
      final r = checkEInvoiceReadiness(
        invoice: _invoice(),
        seller: _input(_invoice(), _qrIban).seller,
        buyer: _input(_invoice(), _qrIban).buyer,
        iban: _qrIban,
      );
      expect(r.blocking, contains(EInvoiceGap.qrIbanWithoutReference));
      // With a frozen reference, or paid to an ordinary IBAN, it passes.
      for (final (invoice, iban) in [
        (_invoice(frozenQrr: _frozenF), _qrIban),
        (_invoice(), _iban),
      ]) {
        expect(
          checkEInvoiceReadiness(
            invoice: invoice,
            seller: _input(invoice, iban).seller,
            buyer: _input(invoice, iban).buyer,
            iban: iban,
          ).gaps,
          isNot(contains(EInvoiceGap.qrIbanWithoutReference)),
        );
      }
    });

    test('UBL and CII refuse to write it', () {
      final input = _input(_invoice(), _qrIban);
      expect(() => buildInvoiceUbl(input), throwsArgumentError);
      expect(() => buildInvoiceCii(input), throwsArgumentError);
    });

    test('a credit note to a QR-IBAN asks for no payment and is written', () {
      final input = _input(
        _invoice(number: 'AV-2026-0001', cents: -12000),
        _qrIban,
      );
      expect(XmlDocument.parse(buildInvoiceUbl(input)).findAllElements('cbc:PaymentID'), isEmpty);
      expect(XmlDocument.parse(buildInvoiceCii(input)).findAllElements('ram:PaymentReference'), isEmpty);
    });

    test('the collision pair: two numbers that derive one reference publish '
        'their two frozen ones, in both syntaxes', () {
      expect(qrrReferenceOf('F-2026-0402'), qrrReferenceOf('U-2026-04-02'));
      final f = _input(_invoice(number: 'F-2026-0402', frozenQrr: _frozenF), _qrIban);
      final u = _input(_invoice(number: 'U-2026-04-02', frozenQrr: _frozenU), _qrIban);
      String ubl(EInvoiceInput i) =>
          XmlDocument.parse(buildInvoiceUbl(i)).findAllElements('cbc:PaymentID').single.innerText;
      String cii(EInvoiceInput i) =>
          XmlDocument.parse(buildInvoiceCii(i)).findAllElements('ram:PaymentReference').single.innerText;
      expect([ubl(f), ubl(u)], [_frozenF, _frozenU]);
      expect([cii(f), cii(u)], [_frozenF, _frozenU]);
      expect(ubl(f), isNot(qrrReferenceOf('F-2026-0402')));
    });
  });
}
