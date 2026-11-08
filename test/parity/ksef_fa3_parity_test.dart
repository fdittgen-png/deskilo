// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the KSeF FA(3) bytes, pinned before and after the
// profile moved into `deskilo_jurisdiction_pl`. The goldens were written by
// the builder that lived in the invoice model and are compared byte for byte:
// a one-character change to any element fails here, whatever the schema says.
// Rewrite only with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/channel_einvoice_xml.dart';
import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

Invoice _invoice({
  int gross = 24600,
  double percent = 23,
  String category = 'S',
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
    number: 'FV/2026/09/42',
    issuedAt: DateTime.utc(2026, 9, 30),
    period: '2026-09',
    title: '2026-09',
    lines: [
      InvoiceLine(
        kind: 'subscription',
        label: '50',
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
    currency: 'PLN',
    memberName: 'Pracownia',
    memberAddress: '',
    workspaceName: 'Przestrzen',
    workspaceAddress: '',
    issuerName: 'Flo',
    signature: 'f' * 64,
    replacesNumber: replacesNumber,
  );
}

const _seller = InvoiceParty(
  name: 'Przestrzen Testowa Sp. z o.o.',
  street: 'ul. Prosta 1',
  city: 'Warszawa',
  postalCode: '00-850',
  country: 'PL',
  vatId: 'PL 526-000-12-46',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Pracownia Polnoc Sp. z o.o.',
  street: 'ul. Dluga 5',
  city: 'Krakow',
  postalCode: '31-147',
  country: 'PL',
  vatId: 'PL6750001923',
);

String _xml(
  Invoice invoice, {
  InvoiceParty buyer = _buyer,
  DateTime? correctedIssuedAt,
  String iban = '',
  DateTime? dueDate,
}) => buildChannelEInvoiceXml(
  EInvoiceFormat.ksefFa3,
  EInvoiceInput(
    invoice: invoice,
    seller: _seller,
    buyer: buyer,
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    iban: iban,
    dueDate: dueDate,
    reference: ActiveTaxReference.current,
  ),
  correctedIssuedAt: correctedIssuedAt,
);

void main() {
  test('the FA(3) bytes are what the invoice model wrote before the move', () {
    expectParity(
      dir: 'test/parity/golden/ksef_fa3',
      text: {
        'ordinary_polish_buyer.xml': _xml(_invoice()),
        'reduced_rate_8.xml': _xml(_invoice(percent: 8, gross: 10800)),
        'zero_rated_export.xml': _xml(
          _invoice(percent: 0, category: 'G', gross: 10000),
        ),
        'exempt.xml': _xml(_invoice(percent: 0, category: 'E', gross: 10000)),
        'domestic_reverse_charge.xml': _xml(
          _invoice(percent: 0, category: 'AE', gross: 10000),
        ),
        'eu_reverse_charge_german_buyer.xml': _xml(
          _invoice(percent: 0, category: 'AE', gross: 10000),
          buyer: _buyer.copyWith(country: 'DE', vatId: 'DE123456789'),
        ),
        'greek_buyer_el.xml': _xml(
          _invoice(),
          buyer: _buyer.copyWith(country: 'GR', vatId: 'GR123456789'),
        ),
        'northern_ireland_buyer_xi.xml': _xml(
          _invoice(),
          buyer: _buyer.copyWith(country: 'GB', vatId: 'XI123456789'),
        ),
        'non_eu_buyer.xml': _xml(
          _invoice(),
          buyer: _buyer.copyWith(country: 'CH', vatId: 'CHE123456789'),
        ),
        'private_buyer_brak_id.xml': _xml(
          _invoice(),
          buyer: _buyer.copyWith(vatId: ''),
        ),
        'correction_with_corrected_date.xml': _xml(
          _invoice(gross: -24600, replacesNumber: 'FV/2026/08/7'),
          correctedIssuedAt: DateTime.utc(2026, 8, 31),
        ),
        'correction_date_defaults_to_issue_date.xml': _xml(
          _invoice(gross: -24600, replacesNumber: 'FV/2026/08/7'),
        ),
        'payment_due_and_account.xml': _xml(
          _invoice(),
          iban: 'PL61 1090 1014 0000 0712 1981 2874',
          dueDate: DateTime.utc(2026, 10, 14),
        ),
      },
    );
  });
}
