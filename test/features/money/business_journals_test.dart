// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 — the business's accounting journals. Every export the app writes
// reads them through one accessor: the FEC from the invoices (its lettering
// included), the local book's FEC, the generic journal, the SAF-T ledgers and
// the printed books. With none set, the country add-on's codes are written
// (the FEC goldens stay byte for byte). A value is whole or refused whole,
// by the same rules the server holds: never cleaned into another journal.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/accounting_journals.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_ledger.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/fec_postings.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _business = FecJournals(
  sales: FecJournal(code: 'VT', label: 'Ventes clients'),
  bank: FecJournal(code: 'BNP', label: 'Banque BNP'),
  purchases: FecJournal(code: 'AC', label: 'Achats'),
  misc: FecJournal(code: 'DIV', label: 'Divers'),
);

const _company = InvoiceParty(
  name: 'Space SAS',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
);

/// The records of a FEC, each a list of its fields.
List<List<String>> _records(String fec) => [
  for (final line in fec.split('\r\n').skip(1))
    if (line.isNotEmpty) line.split('\t'),
];

String _derivedFec(FecAccounts accounts) => buildFecFile(
  FecRequest(
    currency: 'EUR',
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    company: _company,
    accounts: accounts,
    lineText: (line) => line.label,
    reference: ActiveTaxReference.current,
  ),
);

BookAccount _account(String code, AccountType type) => BookAccount(
  id: 'acc-$code',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  code: code,
  name: 'Compte $code',
  type: type,
  isPosting: true,
  origin: AccountOrigin.manual,
  revision: 1,
);

BookMapping _map(BookRole role, String code) => BookMapping(
  id: role.wire,
  workspaceId: 'ws',
  issuerSiteId: 'site',
  role: role,
  accountId: 'acc-$code',
  effectiveFrom: DateTime(2020),
  revision: 1,
);

void main() {
  final postings = postingsOf(
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    book: PostingBook(
      accounts: [
        _account('411000', AccountType.asset),
        _account('512000', AccountType.asset),
        _account('706000', AccountType.income),
        _account('445710', AccountType.liability),
        _account('654000', AccountType.expense),
      ],
      mappings: [
        _map(BookRole.customers, '411000'),
        _map(BookRole.bank, '512000'),
        _map(BookRole.revenue, '706000'),
        _map(BookRole.vatOutput, '445710'),
        _map(BookRole.writeOff, '654000'),
      ],
      issuerSiteId: 'site',
    ),
    groupOf: (InvoiceVatTotal _) => '',
  ).postings;
  final parties = {
    for (final i in SeededExportYear.invoices)
      i.id: const PostingParty(kind: 'member', number: 'M-7', name: 'Ana'),
  };

  group('the accessor', () {
    test('nothing stored: the add-on\'s journals', () {
      expect(accountingJournalsOf(const {}), FecJournals.installed());
    });

    test('a stored value: the business\'s', () {
      expect(accountingJournalsOf(_business.toJson()), _business);
    });

    test('a value that is not whole is not read as journals', () {
      final partial = {..._business.toJson()}..remove('misc');
      expect(FecJournals.fromJson(partial), isNull);
      expect(accountingJournalsOf(partial), FecJournals.installed());
    });
  });

  group('the FEC from the invoices', () {
    final standard = _records(_derivedFec(const FecAccounts()));
    final business = _records(
      _derivedFec(const FecAccounts().withJournals(_business)),
    );

    test('writes the business\'s codes and labels, and numbers its entries '
        'with them', () {
      final installed = FecJournals.installed();
      final byCode = {for (final (role, j) in installed.byRole) j.code: role};
      final mine = {for (final (role, j) in _business.byRole) role: j};
      expect(business, hasLength(standard.length));
      for (final (i, row) in business.indexed) {
        final role = byCode[standard[i][0]]!;
        expect(row[0], mine[role]!.code, reason: 'JournalCode, row $i');
        expect(row[1], mine[role]!.label, reason: 'JournalLib, row $i');
        expect(
          row[2],
          startsWith('${mine[role]!.code}-'),
          reason: 'EcritureNum, row $i',
        );
      }
    });

    test('keeps every record whole: the same number of fields', () {
      for (final (i, row) in business.indexed) {
        expect(row, hasLength(standard[i].length), reason: 'row $i');
      }
    });
  });

  test('the local book\'s FEC writes the business\'s journals', () {
    final written = buildFecFromPostings(
      postings,
      accountNames: const {'411000': 'Clients', '512000': 'Banques'},
      parties: parties,
      journals: _business,
    );
    expect(written.blockers, isEmpty);
    final rows = _records(written.file);
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(['VT', 'BNP', 'AC', 'DIV'], contains(row[0]));
      expect(row[2], startsWith('${row[0]}-'));
    }
    expect({for (final r in rows) r[0]}, containsAll(['VT', 'BNP']));
    expect(
      rows.firstWhere((r) => r[0] == 'VT')[1],
      'Ventes clients',
      reason: 'the label of the business\'s sales journal',
    );
  });

  test('the generic journal and the SAF-T ledgers number with the '
      'business\'s codes', () {
    final code = journalCodeOf(_business);
    final documents = genericJournalDocuments(postings, journalCode: code);
    expect(documents, isNotEmpty);
    final journals = safTPostedJournals(postings, journalCode: code);
    expect([for (final (id, _, _) in journals) id], containsAll(['VT', 'BNP']));
    expect(journalCodeOf(null), isNull, reason: 'none given: the engine\'s');
  });

  test('the printed books head each journal with the business\'s code', () {
    final ledger = BookLedger(
      postings: postings,
      year: FiscalYear(DateTime(2026), DateTime(2026, 12, 31)),
      journals: _business,
    );
    expect(ledger.codeOf(PostingJournal.sales), 'VT');
    expect(
      ledger.entriesOf(PostingJournal.sales).first.entry,
      startsWith('VT-'),
    );
  });

  group('a value is whole or refused whole', () {
    FecJournals withSales(String code, {String label = 'Ventes'}) =>
        FecJournals(
          sales: FecJournal(code: code, label: label),
          bank: _business.bank,
          purchases: _business.purchases,
          misc: _business.misc,
        );

    test('the business\'s value is whole', () {
      expect(journalsProblem(_business), isNull);
    });

    for (final (name, journals, problem) in [
      ('an empty code', withSales(''), JournalProblem.code),
      ('a blank label', withSales('VT', label: '  '), JournalProblem.label),
      ('a line break', withSales('VT\nX'), JournalProblem.character),
      ('a carriage return', withSales('VT\r'), JournalProblem.character),
      (
        'a tab in a label',
        withSales('VT', label: 'A\tB'),
        JournalProblem.character,
      ),
      ('a pipe', withSales('V|T'), JournalProblem.character),
      ('a code used twice', withSales('BNP'), JournalProblem.duplicate),
    ]) {
      test('$name is refused', () {
        final found = journalsProblem(journals);
        expect(found?.problem, problem);
      });
    }

    test('the Demo keeps a whole value and refuses one that is not', () async {
      final workspaces = FakeWorkspaceRepository.withWorkspace();
      final id = workspaces.workspaces.first.id;
      expect(
        await workspaces.setAccountingJournals(id, _business.toJson()),
        isNull,
      );
      expect(
        workspaces.workspaces.first.accountingJournals,
        _business.toJson(),
      );
      expect(
        await workspaces.setAccountingJournals(id, withSales('BNP').toJson()),
        (problem: 'duplicate', role: 'bank', notAllowed: false),
      );
      expect(
        workspaces.workspaces.first.accountingJournals,
        _business.toJson(),
        reason: 'a refused value leaves the kept one',
      );
    });
  });
}
