// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Spanish registers of issued invoices, pinned BEFORE
// the writers move into the Spanish add-on: the libro registro de facturas
// expedidas (the AEAT's XLSX layout, as the cells of its sheet), the SII
// message (SuministroLRFacturasEmitidas), the modelo 347 list and the
// Verifactu record chain, for domestic, EU and non-EU buyers, a reverse
// charge (US buyer, category G: N2), an exempt supply, a real export (Z: E2,
// clave 02), a domestic reverse charge (AE: S2) and a mixed S3 invoice, a
// credit note (R1), a credit without a frozen reason (R4) and one to a buyer
// without an id (R5), a positive replacement, the 347 line at, one cent
// below and one cent above, a supplied and a missing threshold, a voided
// document, and a second year.
// The goldens are written by the code as it stands and compared byte for byte:
// the move must change none of them. Rewrite only with
// `UPDATE_PARITY_GOLDENS=1`, never under CI. Dates are UTC, so the files do
// not depend on the machine's zone.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/money/es_register_support.dart';

import 'es_register_fixtures.dart';
import 'parity_golden.dart';

void main() {
  final reference = ActiveTaxReference.current;
  final docs2026 = registerDocuments(
    documents(),
    from: DateTime.utc(2026),
    to: DateTime.utc(2027),
  );

  test('the Spanish registers are what they were before the move', () {
    const dir = 'test/parity/golden/es_register';
    final text = <String, String>{};

    text['libro_year.txt'] = sheetText(
      esLibroExpedidas(docs2026, activity: 'A038612', reference: reference),
    );
    text['libro_monthly.txt'] = sheetText(
      esLibroExpedidas(
        docs2026,
        activity: 'A038612',
        monthly: true,
        reference: reference,
      ),
    );
    text['libro_q3.txt'] = sheetText(
      esLibroExpedidas(
        registerDocuments(
          documents(),
          from: DateTime.utc(2026, 7),
          to: DateTime.utc(2026, 10),
        ),
        activity: 'A038612',
        reference: reference,
      ),
    );
    text['sii_year.xml'] = siiFacturasEmitidasXml(
      docs2026,
      vatId: 'ESB12345678',
      name: 'Espacio Coworking, S.L.',
      reference: reference,
    );
    text['sii_q1.xml'] = siiFacturasEmitidasXml(
      registerDocuments(
        documents(),
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 4),
      ),
      vatId: 'ES B1234 5678',
      name: 'Espacio Coworking, S.L.',
      reference: reference,
    );
    final list2026 = modelo347Lines(
      docs2026,
      year: 2026,
      reference: reference,
      immediateSupply: false,
    );
    text['modelo347_2026.csv'] = list2026 == null
        ? 'none'
        : modelo347Csv(list2026.lines, currency: list2026.currency);
    final list2027 = modelo347Lines(
      registerDocuments(
        documents(),
        from: DateTime.utc(2027),
        to: DateTime.utc(2028),
      ),
      year: 2027,
      reference: reference,
      immediateSupply: false,
    );
    text['modelo347_2027.csv'] = list2027 == null
        ? 'none'
        : modelo347Csv(list2027.lines, currency: list2027.currency);

    // The Verifactu chain, record by record, as the AEAT's RegistroAlta.
    final chain = StringBuffer();
    var previous = '';
    var previousNumber = '';
    var previousDate = '';
    for (final invoice in docs2026) {
      final record = verifactuRecordFor(
        invoice: invoice,
        seller: seller,
        buyer: invoice.buyerParty!,
        previousHuella: previous,
        previousNumber: previousNumber,
        previousIssueDate: previousDate,
        generatedAt: DateTime.utc(2026, 11, 2, 10, 30),
      );
      chain
        ..writeln(
          verifactuRecordXml(record, issuerName: 'Espacio Coworking, S.L.'),
        )
        ..writeln('huella=${record.huella}');
      previous = record.huella;
      previousNumber = record.number;
      previousDate = record.issueDate;
    }
    text['verifactu_chain.xml'] = chain.toString();

    expectParity(dir: dir, text: text);
  });

  test('the 347 line comes from the reference: supplied, other, missing', () {
    const dir = 'test/parity/golden/es_register_threshold';
    String csv(TaxReferenceSet set) {
      final list = modelo347Lines(
        docs2026,
        year: 2026,
        reference: set,
        immediateSupply: false,
      );
      return list == null
          ? 'none'
          : modelo347Csv(list.lines, currency: list.currency);
    }

    const row = TaxReferenceRow(
      country: 'ES',
      key: 'modelo347',
      validFrom: '1900-01-01',
      value: ThresholdValue(
        cents: 100000,
        effect: 'annual_operations',
        currency: 'EUR',
      ),
      source: 'test',
      confirmed: false,
    );
    expectParity(
      dir: dir,
      text: {
        'modelo347_supplied_1000.csv': csv(const TaxReferenceSet([row])),
        'modelo347_missing.csv': csv(const TaxReferenceSet([])),
      },
    );
  });

  test('a space on the SII is refused a modelo 347, as before', () {
    expect(
      () => modelo347Lines(
        docs2026,
        year: 2026,
        reference: reference,
        immediateSupply: true,
      ),
      throwsA(isA<Object>()),
    );
  });
}
