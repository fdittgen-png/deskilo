// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — SAF-T Financial from the posting engine, over the seeded year
// (support/seeded_export_year.dart, `acceptance*`): one tree, three
// profiles. The fiscal year runs from 1 April, so the March documents are
// the opening balances. With SAFT_SAMPLES_DIR set, one file per profile
// is written there and `tool/saft/validate.sh` reads each against its
// published schema (test/fixtures/saft/); without it the suite stays offline
// and proves what the files say.
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/saf_t_financial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

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
];

/// The bundled reference without its own `saf_t/` rows, so each test
/// states the map it means; [maps] (the fixture by default) on top.
TaxReferenceSet _reference({List<TaxReferenceRow>? maps}) => TaxReferenceSet([
  for (final r in ActiveTaxReference.current.rows)
    if (!(r.domain == TaxDomain.accountMap && r.key.startsWith('saf_t/'))) r,
  ...maps ?? _maps,
]);

InvoiceParty _company(String country) => InvoiceParty(
  name: 'Cowork',
  street: 'Storgata 1',
  city: country == 'NO' ? 'Oslo' : 'Luxembourg',
  postalCode: country == 'NO' ? '0155' : 'L-1611',
  country: country,
  legalId: '999999999',
  vatId: country == 'NO' ? 'NO999999999MVA' : 'LU12345678',
  vatRegime: 'standard',
);

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
}) => SafTFinancialRequest(
  profile: profile,
  period: _period,
  postings: [
    for (final p in _all)
      if (_period.contains(p.date)) p,
  ],
  opening: [
    for (final p in _all)
      if (p.date.isBefore(_period.from)) p,
  ],
  accountNames: {for (final (_, code, _, name) in _chart) code: name},
  accountTypes: {for (final (_, code, type, _) in _chart) code: type},
  parties: _parties,
  partyDetails:
      partyDetails ??
      {
        safTPartyKey('member', _memberNumber): const SafTParty(
          name: 'Ana',
          street: '1 rue de la Gare',
          city: 'Esch-sur-Alzette',
          postalCode: 'L-4002',
          country: 'LU',
        ),
        safTPartyKey('supplier', '17'): const SafTParty(
          name: 'Nettoyage Pézenas',
          city: 'Pézenas',
          postalCode: '34120',
          country: 'FR',
        ),
      },
  company: company ?? _company(country),
  contact: contact,
  currency: 'EUR',
  softwareVersion: '1.0.3',
  createdAt: DateTime(2027, 3, 5),
  reference: reference ?? _reference(),
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

int _cents(String text) => (double.parse(text) * 100).round();

int _text(XmlElement e, String name) =>
    _cents(e.findElements(name).single.innerText);

void main() {
  final samples = Platform.environment['SAFT_SAMPLES_DIR'];

  test('the seeded year has both sides of the fiscal year start', () {
    expect(_request(SafTFinancialProfile.oecd).opening, isNotEmpty);
    expect(_request(SafTFinancialProfile.oecd).postings, isNotEmpty);
  });

  for (final (profile, country) in const [
    (SafTFinancialProfile.oecd, 'FR'),
    (SafTFinancialProfile.norway, 'NO'),
    (SafTFinancialProfile.luxembourg, 'LU'),
  ]) {
    group(profile.formatId, () {
      final doc = _file(_request(profile, country: country));
      final ledger = doc.findAllElements('GeneralLedgerEntries').single;
      final lines = ledger.findAllElements('Line').toList();
      bool debit(XmlElement l) => l.findElements('DebitAmount').isNotEmpty;
      int lineAmount(XmlElement l) => _cents(
        l
            .findElements(debit(l) ? 'DebitAmount' : 'CreditAmount')
            .single
            .findElements('Amount')
            .single
            .innerText,
      );

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
          final own = t.findElements('Line').toList();
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
        // March's sale is still open on the customers on 1 April.
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
}
