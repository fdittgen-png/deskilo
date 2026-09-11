// SPDX-License-Identifier: 0BSD
//
// #1091 — the line's quantity was chosen by whether the GROSS amount
// divides evenly by it, and the unit price was then emitted NET. When
// the net does not divide by the same quantity, the two disagree:
//
//     quantity 4, €10.00 gross at 20%  →  net 8.33
//     unit price 8.33 ~/ 4 = 2.08      →  2.08 × 4 = 8.32 ≠ 8.33
//
// A strict EN 16931 validator rejects that (BR-CO-… line arithmetic),
// and since #568 the same XML also goes straight to the customer, so a
// malformed document reaches two audiences.
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Gross 1000 divides by 4; its net (833) does not. Exactly the shape
/// that produced 2.08 × 4 ≠ 8.33.
const _awkward = InvoiceLine(
  kind: 'overage',
  label: 'Half-days',
  quantity: 4,
  amountCents: 1000,
  vatPercent: 20,
);

Invoice _invoice() => Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0009',
      issuedAt: DateTime(2026, 7, 26),
      period: '2026-07',
      title: '2026-07',
      lines: const [_awkward],
      totalCents: 1000,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test\n34120 Pézenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
    );

const _seller = InvoiceParty(
  name: 'Test Space',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812345678',
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

/// quantity × unit price must equal the line's own net amount.
void expectConsistent(String quantity, String unitPrice, String lineNet) {
  final q = double.parse(quantity);
  final unit = double.parse(unitPrice);
  final net = double.parse(lineNet);
  expect((q * unit - net).abs() < 0.005, isTrue,
      reason: '$quantity × $unitPrice = ${q * unit}, but the line says $net');
}

void main() {
  test('UBL: quantity × unit price equals the line net', () {
    final doc = XmlDocument.parse(buildInvoiceUbl(
      invoice: _invoice(),
      seller: _seller,
      buyer: _buyer,
      iban: '',
      lineText: (line) => invoiceLineText(const ReportStrings(), line),
    ));
    final line = doc.findAllElements('cac:InvoiceLine').first;
    final quantity =
        line.findElements('cbc:InvoicedQuantity').first.innerText;
    final lineNet =
        line.findElements('cbc:LineExtensionAmount').first.innerText;
    final unit = line
        .findAllElements('cbc:PriceAmount')
        .first
        .innerText;
    expectConsistent(quantity, unit, lineNet);
  });

  test('CII: quantity × unit price equals the line net', () {
    final doc = XmlDocument.parse(buildInvoiceCii(
      invoice: _invoice(),
      seller: _seller,
      buyer: _buyer,
      iban: '',
      lineText: (line) => invoiceLineText(const ReportStrings(), line),
    ));
    final line = doc
        .findAllElements('ram:IncludedSupplyChainTradeLineItem')
        .first;
    final quantity =
        line.findAllElements('ram:BilledQuantity').first.innerText;
    final unit =
        line.findAllElements('ram:ChargeAmount').first.innerText;
    final lineNet = line
        .findAllElements('ram:LineTotalAmount')
        .first
        .innerText;
    expectConsistent(quantity, unit, lineNet);
  });
}
