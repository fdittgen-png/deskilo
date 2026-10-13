// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — a Swiss seller's invoice ends on the QR-bill: its own A4 page,
// built only where the guidelines can be met (a Swiss account, a positive
// total, CHF or EUR, not a proforma, not voided).
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill_invoice.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill_pdf.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _strings = InvoicePdfStrings(
  invoiceTitle: 'Rechnung',
  issuedOn: 'Datum',
  issuedBy: 'Von',
  billedTo: 'An',
  total: 'Total',
  signature: 'Signatur',
  voided: '',
  replaces: '',
  description: '',
  charges: '',
  payments: '',
  annex: '',
  attendance: '',
  activity: '',
  reserved: '',
  page: 'Seite',
);

const _words = SwissQrBillStrings(
  receipt: 'Empfangsschein',
  paymentPart: 'Zahlteil',
  account: 'Konto / Zahlbar an',
  reference: 'Referenz',
  additionalInfo: 'Zusätzliche Informationen',
  payableBy: 'Zahlbar durch',
  payableByAddress: 'Zahlbar durch (Name/Adresse)',
  currency: 'Währung',
  amount: 'Betrag',
  acceptancePoint: 'Annahmestelle',
  separate: 'Vor der Einzahlung abzutrennen',
);

Invoice _invoice({
  int total = 10810,
  String currency = 'CHF',
  String country = 'CH',
  DateTime? voidedAt,
}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm-1',
  number: 'INV-2026-0042',
  issuedAt: DateTime(2026, 10),
  title: '2026-10',
  lines: [InvoiceLine(kind: 'subscription', label: '50', amountCents: total)],
  totalCents: total,
  currency: currency,
  memberName: 'Pia Rutschmann',
  memberAddress: 'Grosse Marktgasse 28, 9400 Rorschach',
  workspaceName: 'Cowork AG',
  workspaceAddress: 'Rue du Lac 1268, 2501 Biel',
  issuerName: 'Cowork AG',
  signature: 'a' * 64,
  voidedAt: voidedAt,
  sellerParty: InvoiceParty(
    name: 'Cowork AG',
    street: 'Rue du Lac 1268',
    postalCode: '2501',
    city: 'Biel',
    country: country,
  ),
  buyerParty: const InvoiceParty(
    name: 'Pia Rutschmann',
    street: 'Grosse Marktgasse 28',
    postalCode: '9400',
    city: 'Rorschach',
    country: 'CH',
  ),
);

const _instructions = PaymentInstructions(
  iban: 'CH93 0076 2011 6238 5295 7',
  qrIban: 'CH44 3199 9123 0008 8901 2',
);

void main() {
  test('a Swiss invoice has a bill from its parties, total and number', () {
    final bill = swissQrBillOf(
      _invoice(),
      iban: _instructions.iban,
      qrIban: _instructions.qrIban,
      workspaceCountry: 'CH',
    )!;
    expect(bill.problems, isEmpty);
    expect(bill.referenceType, 'QRR');
    expect(bill.creditor.street, 'Rue du Lac');
    expect(bill.creditor.houseNumber, '1268');
    expect(bill.debtor!.city, 'Rorschach');
    expect(bill.amountText, '108.10');
    expect(bill.additionalInfo, 'INV-2026-0042');
    // Without a QR-IBAN the ordinary account takes a creditor reference.
    final plain = swissQrBillOf(
      _invoice(currency: 'EUR'),
      iban: 'CH93 0076 2011 6238 5295 7',
      qrIban: '',
      workspaceCountry: 'CH',
    )!;
    expect(plain.referenceType, 'SCOR');
    expect(plain.currency, 'EUR');
  });

  test('no bill where the guidelines cannot be met', () {
    SwissQrBill? none(
      Invoice i, {
      PaymentInstructions p = _instructions,
      bool proforma = false,
    }) => swissQrBillOf(
      i,
      iban: p.iban,
      qrIban: p.qrIban,
      workspaceCountry: 'CH',
      proforma: proforma,
    );
    expect(none(_invoice(country: 'FR')), isNull, reason: 'not a Swiss seller');
    expect(none(_invoice(total: -500)), isNull, reason: 'a credit note');
    expect(none(_invoice(currency: 'USD')), isNull);
    expect(none(_invoice(), proforma: true), isNull);
    expect(none(_invoice(voidedAt: DateTime(2026, 10, 2))), isNull);
    expect(none(_invoice(), p: const PaymentInstructions()), isNull);
    expect(
      none(
        _invoice(),
        p: const PaymentInstructions(iban: 'DE89 3704 0044 0532 0130 00'),
      ),
      isNull,
    );
  });

  test('the invoice PDF carries the bill on a page of its own', () async {
    final bill = swissQrBillOf(
      _invoice(),
      iban: _instructions.iban,
      qrIban: _instructions.qrIban,
      workspaceCountry: 'CH',
    )!;
    Future<Uint8List> render({bool withBill = true}) => buildInvoicePdf(
      invoice: _invoice(),
      strings: _strings,
      money: (c) => '${(c / 100).toStringAsFixed(2)} CHF',
      lineText: (line) => invoiceLineText(const ReportStrings(), line),
      activityText: (entry) => annexEntryText(const ReportStrings(), entry),
      dateLabel: '1.10.2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      qrBillPage: withBill
          ? swissQrBillPage(
              bill: bill,
              strings: _words,
              baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
              boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
            )
          : null,
    );
    int pages(Uint8List b) =>
        RegExp(r'/MediaBox[^\]]*595')
            .allMatches(String.fromCharCodes(b))
            .length;
    final without = await render(withBill: false);
    final with_ = await render();
    expect(pages(without), 1);
    expect(pages(with_), 2);
    expect(String.fromCharCodes(with_.take(5)), '%PDF-');
  });
}
