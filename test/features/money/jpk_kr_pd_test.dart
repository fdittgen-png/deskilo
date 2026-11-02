// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — The Polish profile writes only explicit source facts and balanced
// postings; missing journal, tax and mapping evidence refuses with names.
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_countries.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_facts.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_markers.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_offices.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_writer.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/saf_t_financial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/jpk_kr_pd_sample.dart';

void main() {
  test('official schema keeps required sections and conditional KSeF', () {
    const ns = 'http://www.w3.org/2001/XMLSchema';
    final schema = XmlDocument.parse(
      File('test/fixtures/saft/jpk_kr_pl/JPK_KR_PD_1_v1-1.xsd')
          .readAsStringSync(),
    );
    final elements = schema.findAllElements('element', namespace: ns);
    for (final name in [
      'Naglowek',
      'Podmiot1',
      'ZOiS',
      'Dziennik',
      'KontoZapis',
      'Ctrl',
      'RPD',
      'D_9',
      'D_11',
    ]) {
      final element = elements.firstWhere(
        (e) => e.getAttribute('name') == name,
      );
      expect(element.getAttribute('minOccurs'), isNot('0'), reason: name);
    }
    final ksef = elements.firstWhere((e) => e.getAttribute('name') == 'D_12');
    expect(ksef.getAttribute('minOccurs'), '0');
    // Schema optionality does not waive the documented KSeF condition.
  });
  test(
    'official marker, country and tax-office enumerations are kept exact',
    () {
      const ns = 'http://www.w3.org/2001/XMLSchema';
      final schema = XmlDocument.parse(
        File('test/fixtures/saft/jpk_kr_pl/JPK_KR_PD_1_v1-1.xsd')
            .readAsStringSync(),
      );
      final markerType = schema
          .findAllElements('simpleType', namespace: ns)
          .firstWhere((e) => e.getAttribute('name') == 'TMapKontaPOZ');
      final markers = markerType
          .findAllElements('enumeration', namespace: ns)
          .map((e) => e.getAttribute('value')!)
          .toSet();
      final officesSchema = XmlDocument.parse(
        File('test/fixtures/saft/jpk_kr_pl/KodyUrzedowSkarbowych_v8-0E.xsd')
            .readAsStringSync(),
      );
      final offices = officesSchema
          .findAllElements('enumeration', namespace: ns)
          .map((e) => e.getAttribute('value')!)
          .toSet();
      final countriesSchema = XmlDocument.parse(
        File('test/fixtures/saft/jpk_kr_pl/KodyKrajow_v10-0E.xsd')
            .readAsStringSync(),
      );
      final countries = countriesSchema
          .findAllElements('enumeration', namespace: ns)
          .map((e) => e.getAttribute('value')!)
          .toSet();
      expect(jpkKrPdMarkers, markers);
      expect(jpkKrPdOffices, offices);
      expect(jpkKrPdCountries, countries);
    },
  );

  test('missing supplemental facts refuse without producing XML', () {
    final result = buildJpkKrPd(jpkSampleRequest(null)) as JpkKrPdRefused;
    expect(result.gaps, contains('Income-tax reconciliation K_1–K_8'));
    expect(result.gaps, contains('Journal sequence and responsible person'));
    expect(result.gaps, contains('KSeF applicability and identifier'));
    expect(
      result.gaps,
      contains('Source document and booking dates, amount and line details'),
    );
  });
  test('a counterparty cannot be supplied without a source party', () {
    final result = buildJpkKrPd(
      jpkSampleRequest(
        jpkSampleFacts(
          counterpartyCode: 'P1',
          counterparties: const [
            JpkCounterpartyFact(
              code: 'P1',
              sourceKind: 'supplier',
              sourceNumber: 'S1',
            ),
          ],
        ),
      ),
    ) as JpkKrPdRefused;
    expect(result.gaps, contains('Counterparty source missing INV-1'));
  });
  test('a counterparty must match the source document party', () {
    final result = buildJpkKrPd(
      jpkSampleRequest(
        jpkSampleFacts(
          counterpartyCode: 'P1',
          counterparties: const [
            JpkCounterpartyFact(
              code: 'P1',
              sourceKind: 'supplier',
              sourceNumber: 'S1',
            ),
          ],
        ),
        parties: const {
          'doc': PostingParty(
            kind: 'supplier',
            number: 'S2',
            name: 'Other supplier',
          ),
        },
      ),
    ) as JpkKrPdRefused;
    expect(result.gaps, contains('Counterparty source mismatch INV-1'));
  });
  test('unreferenced counterparty facts are refused', () {
    final result = buildJpkKrPd(
      jpkSampleRequest(
        jpkSampleFacts(
          counterparties: const [
            JpkCounterpartyFact(
              code: 'P1',
              sourceKind: 'supplier',
              sourceNumber: 'S1',
            ),
          ],
        ),
      ),
    ) as JpkKrPdRefused;
    expect(result.gaps, contains('Unreferenced counterparty P1'));
  });
  test('missing responsible person, invalid marker and KSeF are named', () {
    final gaps = (buildJpkKrPd(
      jpkSampleRequest(
        jpkSampleFacts(
          responsible: '',
          marker: 'not-a-code',
          ksefRequired: true,
        ),
      ),
    ) as JpkKrPdRefused).gaps;
    expect(gaps, contains('Responsible person INV-1'));
    expect(gaps, contains('Invalid Polish account marker 100'));
    expect(gaps, contains('KSeF identifier INV-1'));
  });
  test(
    'existing financial export adapter consumes the supplied frozen postings',
    () {
      final source = jpkSampleRequest(jpkSampleFacts());
      final result = buildSafTFinancial(
        SafTFinancialRequest(
          profile: SafTFinancialProfile.poland,
          period: source.period,
          postings: source.postings,
          opening: source.opening,
          accountNames: source.accountNames,
          accountTypes: const {},
          parties: const {},
          partyDetails: const {},
          company: const InvoiceParty(),
          contact: const SafTContact(firstName: '', lastName: ''),
          currency: source.currency,
          softwareVersion: 'test',
          createdAt: source.createdAt,
          reference: const TaxReferenceSet([]),
          polishFacts: source.facts,
        ),
      );
      expect(result, isA<SafTFinancialFile>());
      final document = XmlDocument.parse((result as SafTFinancialFile).xml);
      expect(
        document.findAllElements('D_4').single.innerText,
        source.postings.single.documentNumber,
      );
    },
  );

  test(
    'unverified sequence, mismatched source and balances refuse by name',
    () {
      final result = buildJpkKrPd(
        jpkSampleRequest(
          jpkSampleFacts(
            journalSequenceVerified: false,
            entryDocumentId: 'other',
            closingDebitMinor: 101,
            taxOfficeCode: '9999',
            lineNumbers: const ['1', '1'],
          ),
        ),
      ) as JpkKrPdRefused;
      expect(
        result.gaps,
        containsAll([
          'Verified source journal sequence',
          'Journal source mismatch INV-1',
          'Closing balance mismatch 100',
          'Invalid tax office code',
          'Line numbers INV-1',
        ]),
      );
    },
  );

  test('document amount comes from the source fact, not debit turnover', () {
    final result = buildJpkKrPd(
      jpkSampleRequest(jpkSampleFacts(documentMinor: 90)),
    ) as JpkKrPdFile;
    final doc = XmlDocument.parse(result.xml);
    expect(doc.findAllElements('D_11').single.innerText, '0.90');
    expect(doc.findAllElements('C_2').single.innerText, '0.90');
    expect(doc.findAllElements('C_4').single.innerText, '1.00');
  });
  test('balanced explicit facts produce a JPK document and exact controls', () {
    final result =
        buildJpkKrPd(jpkSampleRequest(jpkSampleFacts())) as JpkKrPdFile;
    final doc = XmlDocument.parse(result.xml);
    expect(doc.rootElement.name.local, 'JPK');
    expect(doc.findAllElements('D_9').single.innerText, 'Auditor');
    expect(doc.findAllElements('C_4').single.innerText, '1.00');
    expect(doc.findAllElements('C_5').single.innerText, '1.00');
    final dir = Platform.environment['JPK_SAMPLES_DIR'];
    if (dir != null) {
      Directory(dir).createSync(recursive: true);
      File('$dir/jpk_kr_pl.xml').writeAsStringSync(result.xml);
    }
  });
}
