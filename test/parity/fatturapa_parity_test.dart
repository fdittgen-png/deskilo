// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the FatturaPA bytes, pinned before and after the profile
// moved into `deskilo_jurisdiction_it`. The goldens were written by the
// builder that lived in the application and are compared byte for byte: a
// one-character change to any element fails here, whatever the schema says.
// Rewrite only with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/channel_einvoice_xml.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _seller = InvoiceParty(
  name: 'Spazio Prova S.r.l.',
  street: 'Via Roma 1',
  city: 'Milano',
  postalCode: '20121',
  country: 'IT',
  subdivision: 'MI',
  vatId: 'IT01234567897',
  vatRegime: 'vat_registered',
);

const _flatRate = InvoiceParty(
  name: 'Ditta Forfettaria',
  street: 'Via Po 3',
  city: 'Torino',
  postalCode: '10121',
  country: 'IT',
  subdivision: 'TO',
  vatId: 'IT01234567897',
  legalId: 'RSSMRA80A01H501U',
);

InvoiceParty _buyer({
  String endpoint = 'KRRH6B9',
  String country = 'IT',
  String scheme = '',
}) => InvoiceParty(
  name: 'Studio Nord S.r.l.',
  street: 'Corso Italia 10',
  city: 'Torino',
  postalCode: '10121',
  country: country,
  vatId: country == 'IT' ? 'IT09876543217' : 'DE123456789',
  endpointId: endpoint,
  endpointScheme: scheme,
);

Invoice _invoice({
  String number = 'IT-2026/0042',
  int gross = 24400,
  double percent = 22,
  String category = 'S',
  int quantity = 1,
  String replacesNumber = '',
}) {
  final net = percent > 0
      ? vatSplit(gross.abs(), percent).netCents
      : gross.abs();
  final signedNet = gross < 0 ? -net : net;
  return Invoice(
    id: 'inv-1',
    workspaceId: 'ws-1',
    memberId: 'member-1',
    number: number,
    issuedAt: DateTime(2026, 9, 30),
    period: '2026-09',
    title: '2026-09',
    lines: [
      InvoiceLine(
        kind: 'subscription',
        label: '50',
        quantity: quantity,
        amountCents: gross,
        vatPercent: percent,
        vatCategory: category,
      ),
    ],
    vatTotals: [
      InvoiceVatTotal(
        percent: percent,
        category: category,
        grossCents: gross,
        netCents: signedNet,
        vatCents: gross - signedNet,
      ),
    ],
    totalCents: gross,
    currency: 'EUR',
    memberName: 'Studio Nord',
    memberAddress: '',
    workspaceName: 'Spazio Prova',
    workspaceAddress: '',
    issuerName: 'Flo',
    signature: 'f' * 64,
    replacesNumber: replacesNumber,
  );
}

String _xml(
  Invoice invoice, {
  InvoiceParty seller = _seller,
  InvoiceParty? buyer,
  String iban = '',
  DateTime? dueDate,
}) => buildChannelEInvoiceXml(
  EInvoiceFormat.fatturaPa,
  EInvoiceInput(
    invoice: invoice,
    seller: seller,
    buyer: buyer ?? _buyer(),
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    iban: iban,
    dueDate: dueDate, reference: ActiveTaxReference.current,
  ),
);

void main() {
  test('the FatturaPA bytes are what the application wrote before the move', () {
    expectParity(
      dir: 'test/parity/golden/fatturapa',
      text: {
        'ordinary_private_buyer.xml': _xml(_invoice()),
        'public_buyer_fpa12.xml': _xml(
          _invoice(),
          buyer: _buyer(endpoint: 'UF1234', scheme: 'IT:IPA'),
        ),
        'pec_buyer.xml': _xml(
          _invoice(),
          buyer: _buyer(endpoint: 'studio@pec.example.it'),
        ),
        'foreign_buyer.xml': _xml(
          _invoice(),
          buyer: _buyer(country: 'DE', endpoint: ''),
        ),
        'credit_note_td04.xml': _xml(
          _invoice(gross: -24400, replacesNumber: 'IT-2026/0010'),
        ),
        'exempt_with_stamp_duty.xml': _xml(
          _invoice(gross: 15000, percent: 0, category: 'E'),
        ),
        'flat_rate_seller_rf19.xml': _xml(
          _invoice(gross: 10000, percent: 0, category: 'O'),
          seller: _flatRate,
        ),
        'long_number_hashed_progressive.xml': _xml(
          _invoice(number: 'INVOICE-2026/0000000042'),
        ),
        'quantity_iban_due_date.xml': _xml(
          _invoice(gross: 36600, quantity: 3),
          iban: 'IT60 X054 2811 1010 0000 0123 456',
          dueDate: DateTime(2026, 10, 30),
        ),
      },
    );
  });
}
