// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — The Polish profile writes only explicit source facts and balanced
// postings; missing journal, tax and mapping evidence refuses with names.
import 'dart:io';

import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
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
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.sectionReconciliation)));
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.sectionJournal)));
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.sectionKsef)));
    expect(
      result.gaps,
      contains(const JpkKrPdGap(JpkKrPdGapCode.sectionSource)),
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
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.counterpartySourceMissing, subject: 'INV-1')));
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
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.counterpartySourceMismatch, subject: 'INV-1')));
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
    expect(result.gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.unreferencedCounterparty, subject: 'P1')));
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
    expect(gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.missing, field: JpkKrPdField.responsiblePerson, subject: 'INV-1')));
    expect(gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.invalidMarker, subject: '100')));
    expect(gaps, contains(const JpkKrPdGap(JpkKrPdGapCode.ksefMissing, subject: 'INV-1')));
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
          const JpkKrPdGap(JpkKrPdGapCode.journalSequenceUnverified),
          const JpkKrPdGap(JpkKrPdGapCode.journalSourceMismatch, subject: 'INV-1'),
          const JpkKrPdGap(JpkKrPdGapCode.closingMismatch, subject: '100'),
          const JpkKrPdGap(JpkKrPdGapCode.invalidOffice),
          const JpkKrPdGap(JpkKrPdGapCode.lineNumbers, subject: 'INV-1'),
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

  test('the same book gives the same bytes, pinned by a golden', () {
    String xml() =>
        (buildJpkKrPd(jpkSampleRequest(jpkSampleFacts())) as JpkKrPdFile).xml;
    final golden = File('test/features/money/goldens/jpk_kr_pl.xml');
    if (Platform.environment['UPDATE_SAFT_GOLDENS'] == '1') {
      golden.writeAsStringSync(xml());
    }
    expect(xml(), golden.readAsStringSync());
  });
}
