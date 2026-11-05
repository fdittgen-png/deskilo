// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — SAF-T Financial from the posting engine, over the seeded year
// (support/seeded_export_year.dart, `acceptance*`): one tree, three
// profiles. The fiscal year runs from 1 April, so the March documents are
// the opening balances. With SAFT_SAMPLES_DIR set, one file per profile
// is written there and `tool/saft/validate.sh` reads each against its
// published schema (test/fixtures/saft/); without it the suite stays offline
// and proves what the files say.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_writer.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/saf_t_financial.dart';
import 'package:deskilo/features/money/domain/saf_t_financial_facts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/jpk_kr_pd_sample.dart';
import 'support/seeded_export_year.dart';

const _site = 'site';
const _memberNumber = 'M-0001';
final _period = FiscalYear(DateTime(2026, 4), DateTime(2027, 3, 31));

/// The issuer's chart, one account per role.
const _chart = <(BookRole, String, AccountType, String)>[
  (BookRole.customers, '1500', AccountType.asset, 'Kundefordringer'),
  (BookRole.bank, '1920', AccountType.asset, 'Bankinnskudd'),
  (BookRole.suppliers, '2400', AccountType.liability, 'Leverandørgjeld'),
  (BookRole.revenue, '3000', AccountType.income, 'Salgsinntekt'),
  (BookRole.vatOutput, '2700', AccountType.liability, 'Utgående mva'),
  (BookRole.vatInput, '2710', AccountType.asset, 'Inngående mva'),
  (BookRole.vatPending, '2705', AccountType.liability, 'Mva til forfall'),
  (BookRole.expenses, '6300', AccountType.expense, 'Leie lokale'),
  (BookRole.writeOff, '7830', AccountType.expense, 'Tap på fordringer'),
];

PostingBook _book() => PostingBook(
  accounts: [
    for (final (_, code, type, name) in _chart)
      BookAccount(
        id: 'acc-$code',
        workspaceId: 'ws',
        issuerSiteId: _site,
        code: code,
        name: name,
        type: type,
        isPosting: true,
        origin: AccountOrigin.manual,
        revision: 1,
      ),
  ],
  mappings: [
    for (final (role, code, _, _) in _chart)
      BookMapping(
        id: role.wire,
        workspaceId: 'ws',
        issuerSiteId: _site,
        role: role,
        accountId: 'acc-$code',
        effectiveFrom: DateTime(2020),
        revision: 1,
      ),
  ],
  issuerSiteId: _site,
);

String _group(double percent) => percent >= 20 ? 'standard' : 'reduced';

/// The seeded year's postings, as `compute_postings` books them.
final List<Posting> _all = () {
  final book = _book();
  return [
    ...postingsOf(
      invoices: SeededExportYear.acceptanceInvoices,
      matches: SeededExportYear.acceptanceMatches,
      book: book,
      groupOf: (t) => _group(t.percent),
    ).postings,
    ...purchasePostingsOf(
      purchases: [SeededExportYear.supplierBill],
      book: book,
      groupOf: _group,
    ),
  ]..sort(comparePostings);
}();

final _parties = <String, PostingParty>{
  for (final i in SeededExportYear.acceptanceInvoices)
    i.id: const PostingParty(
      kind: 'member',
      number: _memberNumber,
      name: 'Ana',
    ),
  SeededExportYear.supplierBill.summary.id: const PostingParty(
    kind: 'supplier',
    number: '17',
    name: 'Nettoyage Pézenas',
  ),
};

TaxReferenceRow _row(String country, String key, Map<String, Object?> value) =>
    TaxReferenceRow.fromJson({
      'domain': 'account_map',
      'country': country,
      'key': key,
      'valid_from': '1900-01-01',
      'value': {'format': 'saf_t', 'role': key.substring(6), ...value},
      'source': 'test fixture',
      'confirmed': false,
    });

/// The fixture chart maps: Norway's grouping codes (næringsspesifikasjon)
/// and standard VAT codes, Luxembourg's standard accounts.
final _maps = <TaxReferenceRow>[
  for (final (role, category, code) in const [
    ('customers', 'balanseverdiForOmloepsmiddel', '1500'),
    ('bank', 'balanseverdiForOmloepsmiddel', '1920'),
    ('suppliers', 'kortsiktigGjeld', '2400'),
    ('revenue', 'salgsinntekt', '3000'),
    ('vat_output', 'kortsiktigGjeld', '2740'),
    ('vat_input', 'kortsiktigGjeld', '2740'),
    ('vat_pending', 'kortsiktigGjeld', '2740'),
    ('expenses', 'annenDriftskostnad', '6300'),
    ('write_off', 'annenDriftskostnad', '7830'),
  ])
    _row('NO', 'saf_t/$role', {'account': code, 'label': category}),
  for (final (key, code) in const [
    ('saf_t/tax:output:standard', '3'),
    ('saf_t/tax:output:reduced', '33'),
    ('saf_t/tax:input:standard', '1'),
    ('saf_t/tax:input:reduced', '13'),
  ])
    _row('NO', key, {'tax_code': code}),
  for (final (role, code) in const [
    ('customers', '401100'),
    ('bank', '513100'),
    ('suppliers', '441100'),
    ('revenue', '703000'),
    ('vat_output', '461410'),
    ('vat_input', '421610'),
    ('vat_pending', '461418'),
    ('expenses', '611100'),
    ('write_off', '645100'),
  ])
    _row('LU', 'saf_t/$role', {'account': code}),
  // #2379 — Romania: the synthetic account of the national chart (OMFP
  // 1802/2014) and its function; ANAF's VAT codes by rate (D406
  // nomenclature, sheets Livrari and Achizitii ded 100%).
  for (final (role, code, function) in const [
    ('customers', '4111', 'Activ'),
    ('bank', '5121', 'Activ'),
    ('suppliers', '401', 'Pasiv'),
    ('revenue', '704', 'Pasiv'),
    ('vat_output', '4427', 'Pasiv'),
    ('vat_input', '4426', 'Activ'),
    ('vat_pending', '4428', 'Bifunctional'),
    ('expenses', '628', 'Activ'),
    ('write_off', '654', 'Activ'),
  ])
    _row('RO', 'saf_t/$role', {'account': code, 'label': function}),
  // #2379 — Austria: a TEST mapping onto accounts of the österreichischer
  // Einheitskontenrahmen (EKR), not the reviewed reference rows (those come
  // from the BMF's EKR für SAF-T list).
  for (final (role, code, label) in const [
    ('customers', '2000', 'Lieferforderungen Inland'),
    ('bank', '2800', 'Guthaben bei Kreditinstituten'),
    ('suppliers', '3300', 'Lieferverbindlichkeiten Inland'),
    ('revenue', '4000', 'Umsatzerlöse'),
    ('vat_output', '3500', 'Umsatzsteuer'),
    ('vat_input', '2500', 'Vorsteuer'),
    ('vat_pending', '3500', 'Umsatzsteuer'),
    ('expenses', '7200', 'Sonstiger Aufwand'),
    ('write_off', '7800', 'Forderungsverluste'),
  ])
    _row('AT', 'saf_t/$role', {'account': code, 'label': label}),
  for (final (key, code) in const [
    ('saf_t/tax:output:21', '310344'),
    ('saf_t/tax:output:11', '310351'),
    ('saf_t/tax:input:21', '301104'),
    ('saf_t/tax:input:11', '301105'),
  ])
    _row('RO', key, {'tax_code': code}),
];

/// #2379 — the standard accounts a person confirmed for the fixture's book
/// accounts (Austria writes only these; the role rows are suggestions).
const _atConfirmed = {
  '1500': AccountMapValue(format: 'saf_t', role: 'customers', account: '2000', label: 'Lieferforderungen Inland'),
  '1920': AccountMapValue(format: 'saf_t', role: 'bank', account: '2800', label: 'Guthaben bei Kreditinstituten'),
  '2400': AccountMapValue(format: 'saf_t', role: 'suppliers', account: '3300', label: 'Lieferverbindlichkeiten Inland'),
  '3000': AccountMapValue(format: 'saf_t', role: 'revenue', account: '4000', label: 'Umsatzerlöse'),
  '2700': AccountMapValue(format: 'saf_t', role: 'vat_output', account: '3500', label: 'Umsatzsteuer'),
  '2710': AccountMapValue(format: 'saf_t', role: 'vat_input', account: '2500', label: 'Vorsteuer'),
  '2705': AccountMapValue(format: 'saf_t', role: 'vat_pending', account: '3510', label: 'Noch nicht geschuldete USt'),
  '6300': AccountMapValue(format: 'saf_t', role: 'expenses', account: '7400', label: 'Mietaufwand 20 %'),
  '7830': AccountMapValue(format: 'saf_t', role: 'write_off', account: '7804', label: 'Abschreibung von Forderungen 20 %'),
};

/// The bundled reference without its own `saf_t/` rows, so each test
/// states the map it means; [maps] (the fixture by default) on top.
TaxReferenceSet _reference({List<TaxReferenceRow>? maps}) => TaxReferenceSet([
  for (final r in ActiveTaxReference.current.rows)
    if (!(r.domain == TaxDomain.accountMap && r.key.startsWith('saf_t/'))) r,
  ...maps ?? _maps,
]);

InvoiceParty _company(String country) => InvoiceParty(
  name: 'Cowork',
  street: country == 'AT' ? 'Mariahilfer Straße 1' : 'Storgata 1',
  city: switch (country) {
    'AT' => 'Wien',
    'NO' => 'Oslo',
    'DK' => 'København Ø',
    'RO' => 'București',
    _ => 'Luxembourg',
  },
  postalCode: switch (country) {
    'AT' => '1060',
    'NO' => '0155',
    'DK' => '2100',
    'RO' => '010011',
    _ => 'L-1611',
  },
  country: country,
  legalId: switch (country) {
    // The Firmenbuch number: the company register's, not the tax office's.
    'AT' => 'FN 123456a',
    'DK' => '10150817',
    'RO' => '14399840',
    _ => '999999999',
  },
  vatId: switch (country) {
    'AT' => 'ATU12345678',
    'NO' => 'NO999999999MVA',
    'DK' => 'DK10150817',
    'RO' => 'RO14399840',
    _ => 'LU12345678',
  },
  vatRegime: 'standard',
);

/// A posting that names no reduced rate group on any line.
bool _standardOnly(Posting p) => p.lines.every((l) => l.qualifier != 'reduced');

SafTFinancialRequest _request(
  SafTFinancialProfile profile, {
  String country = 'NO',
  TaxReferenceSet? reference,
  SafTContact contact = const SafTContact(
    firstName: 'Flo',
    lastName: 'Dittgen',
    phone: '+352 621 000 000',
  ),
  Map<String, SafTParty>? partyDetails,
  InvoiceParty? company,
  // #2379 — Denmark has one VAT rate: its sample is the standard-rate part
  // of the seeded year, as a Danish book would hold it.
  bool standardRateOnly = false,
  String profitBasis = '§ 5 EStG',
  String industryCode = '6820',
  String taxNumber = '12 345/6789',
  bool? smallBusiness = false,
  Map<String, AccountMapValue>? confirmedStandards,
}) => SafTFinancialRequest(
  profile: profile,
  period: _period,
  postings: [
    for (final p in _all)
      if (_period.contains(p.date) && (!standardRateOnly || _standardOnly(p))) p,
  ],
  opening: [
    for (final p in _all)
      if (p.date.isBefore(_period.from) && (!standardRateOnly || _standardOnly(p))) p,
  ],
  accountNames: {for (final (_, code, _, name) in _chart) code: name},
  accountTypes: {for (final (_, code, type, _) in _chart) code: type},
  parties: _parties,
  partyDetails:
      partyDetails ??
      {
        safTPartyKey('member', _memberNumber): SafTParty(
          name: 'Ana',
          street: country == 'AT' ? 'Bahnhofstraße 1' : '1 rue de la Gare',
          city: 'Esch-sur-Alzette',
          postalCode: 'L-4002',
          country: 'LU',
        ),
        safTPartyKey('supplier', '17'): SafTParty(
          name: 'Nettoyage Pézenas',
          // Denmark's address starts with its street.
          street: switch (country) {
            'DK' => '2 quai du Port',
            'AT' => 'Hafenstraße 2',
            _ => '',
          },
          city: 'Pézenas',
          postalCode: '34120',
          country: 'FR',
        ),
      },
  company: company ?? _company(country),
  companyIban: switch (country) {
    'DK' => 'DK5000400440116243',
    'RO' => 'RO49AAAA1B31007593840000',
    _ => '',
  },
  contact: contact,
  currency: 'EUR',
  softwareVersion: '1.0.3',
  createdAt: DateTime(2027, 3, 5),
  reference: reference ?? _reference(),
  profitBasis: profitBasis,
  industryCode: industryCode,
  taxNumber: taxNumber,
  smallBusiness: smallBusiness,
  confirmedStandards: confirmedStandards ?? (country == 'AT' ? _atConfirmed : const {}),
);

XmlDocument _file(SafTFinancialRequest request) =>
    switch (buildSafTFinancial(request)) {
      SafTFinancialFile(:final xml) => XmlDocument.parse(xml),
      SafTFinancialRefused(:final gaps) => fail('refused: $gaps'),
    };

List<SafTGap> _gaps(SafTFinancialRequest request) =>
    switch (buildSafTFinancial(request)) {
      SafTFinancialRefused(:final gaps) => gaps,
      SafTFinancialFile() => fail('expected a refusal'),
    };

String _textOf(XmlElement e, String name) =>
    e.findElements(name).single.innerText;

int _cents(String text) => (double.parse(text) * 100).round();

int _text(XmlElement e, String name) =>
    _cents(e.findElements(name).single.innerText);

void main() {
  final samples = Platform.environment['SAFT_SAMPLES_DIR'];
  if (samples != null) {
    test('writes the Polish profile schema sample', () {
      final result = buildJpkKrPd(jpkSampleRequest(jpkSampleFacts()));
      expect(result, isA<JpkKrPdFile>());
      Directory(samples).createSync(recursive: true);
      File('$samples/jpk_kr_pl.xml').writeAsStringSync((result as JpkKrPdFile).xml);
    });
  }

  test('Polish export names missing source facts instead of inventing them', () {
    final result = buildSafTFinancial(_request(SafTFinancialProfile.poland, country: 'PL'));
    expect(result, isA<SafTFinancialRefused>());
    final gaps = (result as SafTFinancialRefused).gaps;
    expect(gaps.any((gap) => gap.kind == SafTGapKind.polishFact &&
        gap.subject.contains('Income-tax reconciliation')), isTrue);
  });

  test('the seeded year has both sides of the fiscal year start', () {
    expect(_request(SafTFinancialProfile.oecd).opening, isNotEmpty);
    expect(_request(SafTFinancialProfile.oecd).postings, isNotEmpty);
  });

  for (final (profile, country) in const [
    (SafTFinancialProfile.oecd, 'FR'),
    (SafTFinancialProfile.norway, 'NO'),
    (SafTFinancialProfile.luxembourg, 'LU'),
    (SafTFinancialProfile.denmark, 'DK'),
    (SafTFinancialProfile.romania, 'RO'),
  ]) {
    group(profile.formatId, () {
      final doc = _file(
        _request(profile, country: country, standardRateOnly: country == 'DK'),
      );
      final ledger = doc.findAllElements('GeneralLedgerEntries').single;
      // Romania's lines are TransactionLines.
      final lineTag = profile.romaniaShape ? 'TransactionLine' : 'Line';
      final lines = ledger.findAllElements(lineTag).toList();
      bool debit(XmlElement l) => l.findElements('DebitAmount').isNotEmpty;
      int lineAmount(XmlElement l) => _cents(
        l
            .findElements(debit(l) ? 'DebitAmount' : 'CreditAmount')
            .single
            .findElements('Amount')
            .single
            .innerText,
      );

      test('the same book gives the same bytes', () {
        String xml() => switch (buildSafTFinancial(
          _request(profile, country: country, standardRateOnly: country == 'DK'),
        )) {
          SafTFinancialFile(:final xml) => xml,
          SafTFinancialRefused(:final gaps) => fail('refused: $gaps'),
        };
        expect(xml(), xml());
      });

      test('declares its namespace and version', () {
        expect(doc.rootElement.namespaceUri, profile.namespace);
        expect(
          doc.findAllElements('AuditFileVersion').single.innerText,
          profile.version,
        );
      });

      test('debits equal credits, and the totals are the lines', () {
        final debits = lines
            .where(debit)
            .map(lineAmount)
            .fold(0, (a, b) => a + b);
        final credits = lines
            .where((l) => !debit(l))
            .map(lineAmount)
            .fold(0, (a, b) => a + b);
        expect(debits, credits);
        expect(_text(ledger, 'TotalDebit'), debits);
        expect(_text(ledger, 'TotalCredit'), credits);
        expect(
          ledger.findElements('NumberOfEntries').single.innerText,
          '${ledger.findAllElements('Transaction').length}',
        );
      });

      test('every transaction balances and references its document', () {
        final numbers = {for (final p in _all) p.documentNumber};
        for (final t in ledger.findAllElements('Transaction')) {
          final own = t.findElements(lineTag).toList();
          expect(
            own.where(debit).map(lineAmount).fold(0, (a, b) => a + b),
            own
                .where((l) => !debit(l))
                .map(lineAmount)
                .fold(0, (a, b) => a + b),
          );
          for (final l in own) {
            expect(
              numbers,
              contains(l.findElements('SourceDocumentID').single.innerText),
            );
          }
        }
      });

      test('the customers are the sub-ledger numbers', () {
        final customers = doc.findAllElements('Customer').toList();
        expect(
          customers.map((c) => c.findElements('CustomerID').single.innerText),
          [_memberNumber],
        );
        final collective = profile == SafTFinancialProfile.norway
            ? customers.single
                  .findAllElements('BalanceAccount')
                  .single
                  .findElements('AccountID')
            : customers.single.findElements('AccountID');
        expect(collective.single.innerText, '1500');
        expect(doc.findAllElements('SupplierID').first.innerText, '17');
      });

      test('each account closes at its opening plus the year', () {
        for (final a in doc.findAllElements('Account')) {
          int side(String prefix) {
            final d = a.findElements('${prefix}DebitBalance');
            return d.isNotEmpty
                ? _cents(d.single.innerText)
                : -_cents(
                    a.findElements('${prefix}CreditBalance').single.innerText,
                  );
          }

          final code = a.findElements('AccountID').single.innerText;
          final year = lines
              .where(
                (l) => l.findElements('AccountID').single.innerText == code,
              )
              .map((l) => debit(l) ? lineAmount(l) : -lineAmount(l))
              .fold(0, (x, y) => x + y);
          expect(side('Closing'), side('Opening') + year, reason: code);
        }
        // March's sale is still open on the customers on 1 April. (Its
        // reduced-rate lines are not in Denmark's standard-rate sample.)
        if (country == 'DK') return;
        final customers = doc
            .findAllElements('Account')
            .firstWhere(
              (a) => a.findElements('AccountID').single.innerText == '1500',
            );
        expect(customers.findElements('OpeningDebitBalance'), isNotEmpty);
      });

      test('a tax line carries its code from the dated tax table', () {
        final codes = {
          for (final d in doc.findAllElements('TaxCodeDetails'))
            d.findElements('TaxCode').single.innerText,
        };
        final used = doc
            .findAllElements('TaxInformation')
            .map((t) => t.findElements('TaxCode').single.innerText)
            // Romania's lines without tax carry ANAF's no-tax code.
            .where((code) => code != '000000')
            .toSet();
        expect(used, isNotEmpty);
        expect(codes, containsAll(used));
      });

      if (samples != null) {
        test('writes its sample', () {
          Directory(samples).createSync(recursive: true);
          File('$samples/${profile.formatId}.xml')
              .writeAsStringSync(doc.toXmlString());
        });
      }
    });
  }

  // #2379 — Austria's SAF-T AT 1.01: the OECD 1.0 tree of its own writer.
  group('saft_at', () {
    const profile = SafTFinancialProfile.austria;
    SafTFinancialRequest at({String profitBasis = '§ 5 EStG', String industryCode = '6820'}) =>
        _request(profile, country: 'AT', profitBasis: profitBasis, industryCode: industryCode);
    final doc = _file(at());
    final root = doc.rootElement;

    test('declares the BMF namespace, version 1.01 and the header the schema requires', () {
      expect(root.namespaceUri, 'urn:OECD:StandardAuditFile-Taxation:AT_1.01');
      final h = root.findElements('Header').single;
      expect(h.childElements.map((e) => e.name.local).take(11), [
        'TaxID', 'CompanyName', 'CompanyAddress', 'CompanyID', 'ContactInformation', 'TaxAccountingBasis',
        'TaxEntity', 'FiscalYear', 'StartDate', 'EndDate', 'Kleinunternehmer_AT',
      ]);
      // The tax office's Steuernummer is the TaxRegistrationNumber; the
      // Firmenbuch number is the CompanyID, never in its place.
      final taxId = h.findElements('TaxID').single;
      expect(_textOf(taxId, 'TaxRegistrationNumber'), '12 345/6789');
      expect(_textOf(h, 'CompanyID'), 'FN 123456a');
      expect(_textOf(h, 'Kleinunternehmer_AT'), 'false');
      expect(_textOf(h, 'AuditFileVersion'), '1.01');
      expect(_textOf(h, 'TaxAccountingBasis'), '§ 5 EStG');
      expect(_textOf(h, 'TaxEntity'), '6820');
      final address = h.findElements('CompanyAddress').single;
      expect(_textOf(address, 'BuildingNumber'), '1');
      expect(_textOf(address, 'StreetName'), 'Mariahilfer Straße');
    });

    test('every account names its standard chart account and its opening balance', () {
      final accounts = root.findAllElements('GeneralLedger').toList();
      expect(accounts, isNotEmpty);
      for (final a in accounts) {
        expect(_textOf(a, 'AccountID_oeEKR'), isNotEmpty);
        expect(
          a.findElements('OpeningDebitBalance').length + a.findElements('OpeningCreditBalance').length,
          1,
        );
      }
    });

    test('the ledger balances and its lines carry plain amounts', () {
      final ledger = root.findAllElements('GeneralLedgerEntries').single;
      final lines = ledger.findAllElements('Line').toList();
      expect(lines, isNotEmpty);
      var debit = 0;
      var credit = 0;
      for (final l in lines) {
        expect(_textOf(l, 'PostingText'), isNotEmpty);
        if (l.findElements('DebitAmount').isNotEmpty) {
          debit += _text(l, 'DebitAmount');
        } else {
          credit += _text(l, 'CreditAmount');
        }
      }
      expect(debit, credit);
      expect(_text(ledger, 'TotalDebit'), debit);
      expect(_text(ledger, 'TotalCredit'), credit);
    });

    test('a missing fact is refused, named', () {
      expect(_gaps(at(profitBasis: '', industryCode: '')), containsAll(const [
        SafTGap(SafTGapKind.company, 'TaxAccountingBasis'),
        SafTGap(SafTGapKind.company, 'TaxEntity'),
      ]));
      // No Steuernummer stated: refused, never the Firmenbuch number in its
      // place; the small-business status unknown: refused, never derived.
      final unstated = _request(profile, country: 'AT', taxNumber: '', smallBusiness: null);
      expect(_gaps(unstated), containsAll(const [
        SafTGap(SafTGapKind.company, 'TaxRegistrationNumber'),
        SafTGap(SafTGapKind.company, 'Kleinunternehmer_AT'),
      ]));
      // A role row is only a suggestion: an account nobody confirmed is
      // refused even where the reference has a row for its role.
      expect(
        _gaps(_request(profile, country: 'AT', confirmedStandards: {..._atConfirmed}..remove('2400'))),
        contains(const SafTGap(SafTGapKind.standardAccount, '2400 Leverandørgjeld')),
      );
      expect(
        _gaps(_request(profile, country: 'AT', company: _company('AT').copyWith(street: 'Mariahilfer Straße'))),
        contains(const SafTGap(SafTGapKind.company, 'BuildingNumber')),
      );
    });

    // 0676 — the reviewed rows the app ships, from the BMF's EKR für SAF-T.
    test('with the shipped AT rows a standard-rate book is written, every account on the BMF list', () {
      final ekr = {
        for (final line in File('test/fixtures/saft/saft_at/EKR_fuer_SAF-T.csv')
            .readAsStringSync(encoding: latin1)
            .split('\r\n')
            .skip(1))
          if (line.contains(';')) line.split(';').first,
      };
      bool writesOff(Posting p) => p.lines.any((l) => l.role == BookRole.writeOff);
      final base = _request(profile, country: 'AT', standardRateOnly: true,
          reference: TaxReferenceSet(ActiveTaxReference.current.rows));
      final book = SafTFinancialRequest(
        profile: profile, period: base.period,
        postings: [for (final p in base.postings) if (!writesOff(p)) p],
        opening: [for (final p in base.opening) if (!writesOff(p)) p],
        accountNames: base.accountNames, accountTypes: base.accountTypes, parties: base.parties,
        partyDetails: base.partyDetails, company: base.company, contact: base.contact,
        currency: base.currency, softwareVersion: base.softwareVersion, createdAt: base.createdAt,
        reference: base.reference, profitBasis: '§ 5 EStG', industryCode: '6820',
        taxNumber: '12 345/6789', smallBusiness: false,
      );
      // The person keeps every suggestion of the shipped rows.
      final unconfirmed = safTStandardSuggestions(book);
      final confirmed = SafTFinancialRequest(
        profile: profile, period: book.period, postings: book.postings, opening: book.opening,
        accountNames: book.accountNames, accountTypes: book.accountTypes, parties: book.parties,
        partyDetails: book.partyDetails, company: book.company, contact: book.contact,
        currency: book.currency, softwareVersion: book.softwareVersion, createdAt: book.createdAt,
        reference: book.reference, profitBasis: book.profitBasis, industryCode: book.industryCode,
        taxNumber: book.taxNumber, smallBusiness: book.smallBusiness,
        confirmedStandards: {for (final u in unconfirmed) u.code: ?u.suggestion},
      );
      expect(_gaps(book), isNotEmpty, reason: 'nothing is written from the rows alone');
      final file = _file(confirmed);
      final codes = file.findAllElements('AccountID_oeEKR').map((e) => e.innerText).toSet();
      expect(codes, isNotEmpty);
      expect(ekr.containsAll(codes), isTrue, reason: 'every standard account is on the BMF list: $codes');
      expect(codes, containsAll(['2000', '2800', '4000', '3500']));
    });

    test('with the shipped AT rows a write-off has no suggestion, so it is refused until the person enters one', () {
      final request = _request(profile, country: 'AT', reference: TaxReferenceSet(ActiveTaxReference.current.rows));
      final suggestions = {for (final s in safTStandardSuggestions(request)) s.code: s.suggestion};
      expect(suggestions['7830'], isNull, reason: 'the BMF list has no rate-free write-off account');
      final keptSuggestions = _request(profile, country: 'AT',
          reference: TaxReferenceSet(ActiveTaxReference.current.rows),
          confirmedStandards: {for (final e in suggestions.entries) e.key: ?e.value});
      expect(_gaps(keptSuggestions), contains(const SafTGap(SafTGapKind.standardAccount, '7830 Tap på fordringer')));
    });

    test('what the person confirmed is written, not the role row it departs from', () {
      String oeEkrOf(XmlDocument d, String account) => _textOf(
        d.findAllElements('GeneralLedger').singleWhere((a) => _textOf(a, 'AccountID') == account),
        'AccountID_oeEKR',
      );
      // Suggested from the roles: payables 3300 (domestic), expenses 7200.
      final suggested = {
        for (final s in safTStandardSuggestions(at())) s.code: s.suggestion?.account,
      };
      expect(suggested['2400'], '3300');
      expect(suggested['6300'], '7200');
      // A space whose suppliers are abroad and whose expense is its rent:
      final foreign = _file(_request(profile, country: 'AT', confirmedStandards: {
        ..._atConfirmed,
        '2400': const AccountMapValue(format: 'saf_t', role: 'suppliers', account: '3370', label: 'Lieferverbindlichkeiten sonstiges Ausland'),
      }));
      expect(oeEkrOf(foreign, '2400'), '3370');
      expect(oeEkrOf(foreign, '6300'), '7400');
      expect(oeEkrOf(doc, '2400'), '3300', reason: 'the domestic confirmation of the same account');
    });

    test('a blank confirmed account is no confirmation: refused, the account named', () {
      for (final blank in ['', '   ']) {
        final request = _request(profile, country: 'AT', confirmedStandards: {
          ..._atConfirmed,
          '2400': AccountMapValue(format: 'saf_t', role: 'suppliers', account: blank),
        });
        expect(_gaps(request), contains(const SafTGap(SafTGapKind.standardAccount, '2400 Leverandørgjeld')),
            reason: 'blank "$blank"');
      }
      // A confirmed number with spaces around it is written trimmed.
      final padded = _file(_request(profile, country: 'AT', confirmedStandards: {
        ..._atConfirmed,
        '2400': const AccountMapValue(format: 'saf_t', role: 'suppliers', account: ' 3370 '),
      }));
      expect(
        _textOf(padded.findAllElements('GeneralLedger').singleWhere((a) => _textOf(a, 'AccountID') == '2400'),
            'AccountID_oeEKR'),
        '3370',
      );
    });

    test('a sole proprietor without a Firmenbuch number is written, under its Steuernummer', () {
      final sole = _file(_request(profile, country: 'AT', company: _company('AT').copyWith(legalId: '')));
      final h = sole.findAllElements('Header').single;
      expect(h.findElements('CompanyID'), isEmpty);
      expect(_textOf(h.findElements('TaxID').single, 'TaxRegistrationNumber'), '12 345/6789');
    });

    test('the same book gives the same bytes, pinned by a golden', () {
      String xml() => switch (buildSafTFinancial(at())) {
        SafTFinancialFile(:final xml) => xml,
        SafTFinancialRefused(:final gaps) => fail('refused: $gaps'),
      };
      final golden = File('test/features/money/goldens/saft_at.xml');
      if (Platform.environment['UPDATE_SAFT_GOLDENS'] == '1') golden.writeAsStringSync(xml());
      expect(xml(), golden.readAsStringSync());
    });

    if (samples != null) {
      test('writes its sample', () {
        Directory(samples).createSync(recursive: true);
        File('$samples/${profile.formatId}.xml').writeAsStringSync(doc.toXmlString());
      });
    }
  });

  test('Norway maps each account to its grouping code and each tax to its '
      'standard code', () {
    final doc = _file(_request(SafTFinancialProfile.norway));
    final revenue = doc
        .findAllElements('Account')
        .firstWhere(
          (a) => a.findElements('AccountID').single.innerText == '3000',
        );
    expect(
      revenue.findElements('GroupingCategory').single.innerText,
      'salgsinntekt',
    );
    expect(revenue.findElements('GroupingCode').single.innerText, '3000');
    expect(
      doc.findAllElements('StandardTaxCode').map((e) => e.innerText).toSet(),
      containsAll(['3', '33']),
    );
  });

  test('an unmapped account blocks the profile and is named', () {
    final gaps = _gaps(
      _request(
        SafTFinancialProfile.norway,
        reference: _reference(
          maps: [
            for (final r in _maps)
              if (r.key != 'saf_t/expenses') r,
          ],
        ),
      ),
    );
    expect(gaps, [
      const SafTGap(SafTGapKind.standardAccount, '6300 Leie lokale'),
    ]);
  });

  test('an unmapped tax code blocks Norway and is named', () {
    final gaps = _gaps(
      _request(
        SafTFinancialProfile.norway,
        reference: _reference(
          maps: [
            for (final r in _maps)
              if (r.key != 'saf_t/tax:output:reduced') r,
          ],
        ),
      ),
    );
    expect(gaps, [
      const SafTGap(SafTGapKind.standardTaxCode, 'output:reduced'),
    ]);
  });

  test("Luxembourg's standard accounts come from its own rows", () {
    final doc = _file(_request(SafTFinancialProfile.luxembourg, country: 'LU'));
    expect(
      doc.findAllElements('StandardAccountID').map((e) => e.innerText).toSet(),
      containsAll(['401100', '703000']),
    );
    // Norway's rows answer for Norway only.
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.luxembourg,
          country: 'LU',
          reference: _reference(
            maps: [
              for (final r in _maps)
                if (r.country == 'NO') r,
            ],
          ),
        ),
      ).map((g) => g.kind).toSet(),
      {SafTGapKind.standardAccount},
    );
  });

  test('Luxembourg names a party without a postal address', () {
    final gaps = _gaps(
      _request(
        SafTFinancialProfile.luxembourg,
        country: 'LU',
        partyDetails: const {},
      ),
    );
    expect(gaps, [
      const SafTGap(SafTGapKind.party, '$_memberNumber Address'),
      const SafTGap(SafTGapKind.party, '17 Address'),
    ]);
  });

  test('the contact person is required everywhere, a telephone in the '
      'FAIA shape', () {
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.norway,
          contact: const SafTContact(firstName: '', lastName: 'Dittgen'),
        ),
      ),
      [const SafTGap(SafTGapKind.contact, 'ContactPerson')],
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.oecd,
          country: 'FR',
          contact: const SafTContact(firstName: 'Flo', lastName: 'Dittgen'),
        ),
      ),
      [const SafTGap(SafTGapKind.contact, 'Telephone')],
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.luxembourg,
          country: 'LU',
          contact: const SafTContact(firstName: 'Flo', lastName: 'Dittgen'),
        ),
      ),
      [const SafTGap(SafTGapKind.contact, 'Telephone')],
    );
  });

  test('a document without its party is named, never written without one', () {
    final request = _request(SafTFinancialProfile.oecd, country: 'FR');
    final gaps = _gaps(
      SafTFinancialRequest(
        profile: request.profile,
        period: request.period,
        postings: request.postings,
        opening: request.opening,
        accountNames: request.accountNames,
        accountTypes: request.accountTypes,
        parties: {
          for (final e in _parties.entries)
            if (e.value.kind == 'member') e.key: e.value,
        },
        partyDetails: request.partyDetails,
        company: request.company,
        contact: request.contact,
        currency: request.currency,
        softwareVersion: request.softwareVersion,
        createdAt: request.createdAt,
        reference: request.reference,
      ),
    );
    expect(gaps.map((g) => g.kind).toSet(), {SafTGapKind.party});
    expect(gaps.map((g) => g.subject), contains('B-1'));
  });

  test('the company: its registration number, and the country the profile '
      'declares', () {
    final norwegian = _company('NO');
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.norway,
          company: norwegian.copyWith(legalId: ''),
        ),
      ),
      [const SafTGap(SafTGapKind.company, 'RegistrationNumber')],
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.norway,
          company: norwegian.copyWith(country: 'SE'),
        ),
      ).map((g) => (g.kind, g.subject)),
      contains((SafTGapKind.company, 'Country')),
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.oecd,
          country: 'FR',
          company: _company('FR').copyWith(city: ''),
        ),
      ),
      [const SafTGap(SafTGapKind.company, 'Address')],
    );
  });

  group('#2379 — Romania (D406)', () {
    SafTFinancialRequest ro({
      TaxReferenceSet? reference,
      Map<String, SafTParty>? partyDetails,
    }) => _request(
      SafTFinancialProfile.romania,
      country: 'RO',
      reference: reference,
      partyDetails: partyDetails,
    );

    test('every line names a customer, a supplier and its tax; a line '
        'without VAT carries ANAF\'s no-tax code at zero', () {
      final doc = _file(ro());
      final lines = doc.findAllElements('TransactionLine').toList();
      expect(lines, isNotEmpty);
      for (final l in lines) {
        expect(l.findElements('CustomerID'), hasLength(1));
        expect(l.findElements('SupplierID'), hasLength(1));
        final tax = l.findElements('TaxInformation').single;
        final type = tax.findElements('TaxType').single.innerText;
        final code = tax.findElements('TaxCode').single.innerText;
        if (type == '000') {
          expect(code, '000000');
          expect(_text(tax.findElements('TaxAmount').single, 'Amount'), 0);
        } else {
          expect(type, '300');
          expect({'310344', '310351', '301104', '301105'}, contains(code));
        }
      }
      expect(
        lines.where(
          (l) =>
              l.findAllElements('TaxType').single.innerText == '300' &&
              l.findAllElements('TaxCode').single.innerText == '310344',
        ),
        isNotEmpty,
      );
    });

    test('an account names its national chart account and its function', () {
      final doc = _file(ro());
      final customers = doc
          .findAllElements('Account')
          .firstWhere((a) => a.findElements('AccountID').single.innerText == '1500');
      expect(_textOf(customers, 'StandardAccountID'), '4111');
      expect(_textOf(customers, 'AccountType'), 'Activ');
    });

    test('a party with a registration number carries its name and address',
        () {
      final doc = _file(
        ro(
          partyDetails: {
            safTPartyKey('member', _memberNumber): const SafTParty(
              name: 'Ana SRL',
              street: 'Strada Lipscani 1',
              city: 'București',
              postalCode: '030031',
              country: 'RO',
              vatId: 'RO18547290',
            ),
            safTPartyKey('supplier', '17'): const SafTParty(
              name: 'Nettoyage Pézenas',
              street: '2 quai du Port',
              city: 'Pézenas',
              postalCode: '34120',
              country: 'FR',
            ),
          },
        ),
      );
      final company = doc
          .findAllElements('Customer')
          .single
          .findElements('CompanyStructure')
          .single;
      expect(_textOf(company, 'RegistrationNumber'), 'RO18547290');
      // The name the documents were posted under.
      expect(_textOf(company, 'Name'), 'Ana');
      // A supplier without one is written by its number only.
      expect(
        doc.findAllElements('Supplier').single.findElements('CompanyStructure'),
        isEmpty,
      );
    });

    test('a rate without its ANAF code is named, never written', () {
      final reference = _reference(
        maps: [
          for (final m in _maps)
            if (m.key != 'saf_t/tax:output:21') m,
        ],
      );
      expect(
        _gaps(ro(reference: reference)),
        contains(const SafTGap(SafTGapKind.standardTaxCode, 'output:21')),
      );
    });

    test('a company without its bank account is named', () {
      final request = ro();
      expect(
        _gaps(
          SafTFinancialRequest(
            profile: request.profile,
            period: request.period,
            postings: request.postings,
            opening: request.opening,
            accountNames: request.accountNames,
            accountTypes: request.accountTypes,
            parties: request.parties,
            partyDetails: request.partyDetails,
            company: request.company,
            contact: request.contact,
            currency: request.currency,
            softwareVersion: request.softwareVersion,
            createdAt: request.createdAt,
            reference: request.reference,
          ),
        ),
        [const SafTGap(SafTGapKind.company, 'BankAccount')],
      );
    });
  });

  test('Denmark names a company without its VAT number', () {
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.denmark,
          country: 'DK',
          standardRateOnly: true,
          company: _company('DK').copyWith(vatId: ''),
        ),
      ),
      [const SafTGap(SafTGapKind.company, 'TaxRegistration')],
    );
  });

  test("a field longer than the profile's schema allows is refused, never "
      'cut', () {
    final long = 'N' * 71;
    final lu = _company('LU').copyWith(name: long);
    expect(
      _gaps(
        _request(SafTFinancialProfile.luxembourg, country: 'LU', company: lu),
      ),
      [SafTGap(SafTGapKind.tooLong, 'Name: $long')],
    );
    // Norway's Name takes 256.
    expect(
      buildSafTFinancial(
        _request(
          SafTFinancialProfile.norway,
          company: _company('NO').copyWith(name: long),
        ),
      ),
      isA<SafTFinancialFile>(),
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.luxembourg,
          country: 'LU',
          company: _company('LU').copyWith(postalCode: '1' * 19),
        ),
      ),
      [SafTGap(SafTGapKind.tooLong, 'PostalCode: ${'1' * 19}')],
    );
  });

  test('a tax line whose group has no rate in the country is named', () {
    final reference = TaxReferenceSet([
      for (final r in _reference().rows)
        if (!(r.domain == TaxDomain.rate &&
            r.country == 'NO' &&
            r.key == 'reduced'))
          r,
    ]);
    expect(_gaps(_request(SafTFinancialProfile.norway, reference: reference)), [
      const SafTGap(SafTGapKind.taxRate, 'reduced'),
    ]);
  });

  test('party details come from the posted documents of the fiscal year and '
      'the opening, whatever calendar year they were issued in', () {
    Invoice issued(String id, DateTime at, String city) =>
        SeededExportYear.inv1.copyWith(
          id: id,
          issuedAt: at,
          buyerParty: InvoiceParty(
            name: 'Member $id',
            city: city,
            postalCode: '1',
          ),
        );
    final details = safTPartyDetails(
      parties: const {
        // Opening (March 2026), and February of the next calendar year.
        'march': PostingParty(kind: 'member', number: 'M-1', name: 'A'),
        'february': PostingParty(kind: 'member', number: 'M-2', name: 'B'),
        'bill': PostingParty(kind: 'supplier', number: '17', name: 'C'),
      },
      invoices: [
        issued('march', DateTime(2026, 3, 5), 'Oslo'),
        issued('february', DateTime(2027, 2, 5), 'Bergen'),
        issued('unposted', DateTime(2026, 6, 5), 'Tromsø'),
      ],
      suppliers: const [],
    );
    expect(details.keys, {'member:M-1', 'member:M-2'});
    expect(details['member:M-2']!.city, 'Bergen');
  });

  test("the shipped rows map the seeded chart for Norway; Luxembourg's name "
      'the role they do not cover', () {
    expect(
      buildSafTFinancial(
        _request(
          SafTFinancialProfile.norway,
          reference: ActiveTaxReference.current,
        ),
      ),
      isA<SafTFinancialFile>(),
    );
    expect(
      _gaps(
        _request(
          SafTFinancialProfile.luxembourg,
          country: 'LU',
          reference: ActiveTaxReference.current,
        ),
      ),
      [const SafTGap(SafTGapKind.standardAccount, '7830 Tap på fordringer')],
    );
  });

  test("the shipped rows map the seeded chart and its rates for Romania's "
      'D406 (0626)', () {
    expect(
      buildSafTFinancial(
        _request(
          SafTFinancialProfile.romania,
          country: 'RO',
          reference: ActiveTaxReference.current,
        ),
      ),
      isA<SafTFinancialFile>(),
    );
  });
}
