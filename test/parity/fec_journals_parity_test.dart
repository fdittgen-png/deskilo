// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the one FEC journal row no golden pinned, BEFORE the
// journal codes move into the French add-on's FEC configuration: the VAT
// released from the pending account on its tax point (OD, `releaseVat`).
// The purchases journal (HA) and the write-off (OD-...-W) are pinned by
// `goldens/seeded_year/fec.txt`, the sales (VE) and bank (BQ) journals by
// `goldens/exports/fec.txt`. The
// golden is written by the code as it stands and compared byte for byte;
// rewrite only with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _seller = InvoiceParty(
  name: 'Space SAS',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
);

Invoice _invoice(String id, String number, DateTime issued, int net, int vat) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-$id',
      number: number,
      issuedAt: issued,
      title: 'Poste $number',
      lines: [
        InvoiceLine(label: 'Desk', amountCents: net + vat, vatPercent: 20),
      ],
      totalCents: net + vat,
      currency: 'EUR',
      memberName: 'Client $id',
      memberAddress: '1 Rue Test, 34120 Pézenas',
      workspaceName: 'Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Owner',
      signature: '',
      vatTotals: [
        InvoiceVatTotal(
          percent: 20,
          category: 'S',
          grossCents: net + vat,
          netCents: net,
          vatCents: vat,
        ),
      ],
      sellerParty: _seller,
      buyerParty: const InvoiceParty(name: 'Client', country: 'FR'),
    );

String _fec() {
  // the VAT of the invoice is due on a LATER tax point: it waits on the
  // pending account and an OD entry moves it on that day
  final later = _invoice(
    'w3',
    'INV-2026-0103',
    DateTime.utc(2026, 3, 12, 10),
    5000,
    1000,
  );
  return buildFecFile(
    FecRequest(
      currency: 'EUR',
      invoices: [later],
      matches: const {},
      company: _seller,
      accounts: const FecAccounts(),
      lineText: (line) => line.label,
      reference: ActiveTaxReference.current,
      taxPoints: [
        VatTaxPointAmount(
          invoiceId: 'w3',
          on: DateTime.utc(2026, 4, 30),
          percent: 20,
          grossCents: 6000,
          netCents: 5000,
          vatCents: 1000,
        ),
      ],
    ),
  );
}

void main() {
  test('the VAT released on its tax point is booked in the OD journal', () {
    final text = _fec();
    expect(text, contains('\nOD\t'));
    expect(text, contains('OD-INV-2026-0103-T1'));
    expectParity(
      dir: 'test/parity/golden/fec_journals',
      text: {'fec.txt': text},
    );
  });
}
