// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the book reports over the seeded year's postings (the same ones
// the posted FEC writes): the trial balance sums to zero, the auxiliary
// balance adds up to its collective account, the general ledger's running
// balance ends where the trial balance does, the journals' summary is the
// sum of their entries, and the balance's revenue and collected VAT equal
// what the tax-point engine (the Dart twin of compute_vat_return) declares
// for the year on the debits, the write-off's regularisation apart.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_reports.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/presentation/book_report_actions.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/money/presentation/vat_report_actions.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _site = 'site';
const _debits = {'seller_country': 'FR', 'vat_exigibility': 'invoice'};

const _chart = <(BookRole, String?, String, AccountType, String)>[
  (BookRole.customers, null, '411000', AccountType.asset, 'Clients'),
  (BookRole.bank, null, '512000', AccountType.asset, 'Banque'),
  (BookRole.suppliers, null, '401000', AccountType.liability, 'Fournisseurs'),
  (BookRole.revenue, null, '706000', AccountType.income, 'Prestations'),
  (BookRole.vatOutput, null, '445711', AccountType.liability, 'TVA 20 %'),
  (BookRole.vatInput, null, '445660', AccountType.asset, 'TVA déductible'),
  (BookRole.vatPending, null, '445740', AccountType.liability, 'TVA attente'),
  (BookRole.expenses, null, '606000', AccountType.expense, 'Achats'),
  (BookRole.writeOff, null, '654000', AccountType.expense, 'Pertes'),
];

final _reduced = ActiveTaxReference.current.groupOfRate('FR', 5.5, 'S');

List<(BookRole, String?, String, AccountType, String)> get _all => [
  ..._chart,
  (BookRole.vatOutput, _reduced, '445713', AccountType.liability, 'TVA 5,5 %'),
];

PostingBook _book() => PostingBook(
  accounts: [
    for (final (_, _, code, type, name) in _all)
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
    for (final (role, qualifier, code, _, _) in _all)
      BookMapping(
        id: '${role.wire}:$qualifier',
        workspaceId: 'ws',
        issuerSiteId: _site,
        role: role,
        qualifier: qualifier,
        accountId: 'acc-$code',
        effectiveFrom: DateTime(2020),
        revision: 1,
      ),
  ],
  issuerSiteId: _site,
);

BookLedger _ledger() {
  final book = _book();
  final sold = postingsOf(
    invoices: SeededExportYear.acceptanceInvoices,
    matches: SeededExportYear.acceptanceMatches,
    book: book,
    groupOf: (t) =>
        ActiveTaxReference.current.groupOfRate('FR', t.percent, t.category),
  );
  final bought = purchasePostingsOf(
    purchases: [SeededExportYear.supplierBill],
    book: book,
    groupOf: (percent) =>
        ActiveTaxReference.current.groupOfRate('FR', percent, 'S'),
  );
  expect(book.blockers, isEmpty);
  return BookLedger(
    postings: [...sold.postings, ...bought]..sort(comparePostings),
    year: FiscalYear(DateTime(2025, 10), DateTime(2026, 9, 30)),
    accountNames: {for (final (_, _, code, _, name) in _all) code: name},
    parties: {
      for (final i in SeededExportYear.acceptanceInvoices)
        i.id: PostingParty(
          kind: 'member',
          number: 'M-0001',
          name: i.memberName,
        ),
      SeededExportYear.supplierBill.summary.id: const PostingParty(
        kind: 'supplier',
        number: '4',
        name: 'Fournisseur SA',
      ),
    },
    functionalCurrency: 'EUR',
  );
}

const BookFormat _plain = (money: _money, date: _date);
String _money(int minor) => '$minor';
String _date(DateTime d) => '${d.year}-${d.month}-${d.day}';

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('the trial balance sums to zero', () {
    final accounts = _ledger().trialBalance();
    expect(accounts, isNotEmpty);
    final debit = accounts.fold(0, (s, a) => s + a.debit);
    final credit = accounts.fold(0, (s, a) => s + a.credit);
    expect(debit, credit);
    expect(accounts.fold(0, (s, a) => s + a.balance), 0);
    expect(accounts.map((a) => a.code), containsAll(['411000', '401000']));
  });

  test('the auxiliary balance adds up to its collective account, under the '
      "FEC's auxiliary accounts", () {
    final books = _ledger();
    final aux = books.auxiliaryBalance();
    final byCode = {for (final a in books.trialBalance()) a.code: a};
    for (final collective in ['411000', '401000']) {
      final of = aux.where((a) => a.collective == collective);
      expect(of, isNotEmpty, reason: collective);
      expect(of.fold(0, (s, a) => s + a.debit), byCode[collective]!.debit);
      expect(of.fold(0, (s, a) => s + a.credit), byCode[collective]!.credit);
    }
    expect(aux.map((a) => a.aux), containsAll(['411M0001', '4014']));
  });

  test("the general ledger's running balance ends at the trial balance", () {
    final books = _ledger();
    final ledger = books.generalLedger();
    for (final a in books.trialBalance()) {
      expect(ledger[a.code]!.last.balance, a.balance, reason: a.code);
    }
    // Entry numbers are the FEC's: a document's second bank entry is -2.
    expect(
      ledger['512000']!.map((l) => l.entry),
      containsAll(['BQ-INV-1', 'BQ-INV-1-2']),
    );
  });

  test("the journals' summary is the sum of their entries", () {
    final books = _ledger();
    for (final t in books.journalTotals()) {
      final entries = books.entriesOf(t.journal);
      expect(entries.length, t.entries);
      final lines = [for (final e in entries) ...e.lines];
      expect(lines.fold(0, (s, l) => s + l.debit.minor), t.debit);
      expect(lines.fold(0, (s, l) => s + l.credit.minor), t.credit);
      expect(t.debit, t.credit, reason: t.journal.code);
    }
    expect(
      books.journalTotals().map((t) => t.journal),
      containsAll([PostingJournal.sales, PostingJournal.bank]),
    );
  });

  test("the balance's revenue and collected VAT equal the year's return on "
      "the debits, the write-off's regularisation apart", () {
    final books = _ledger();
    final accounts = books.trialBalance();
    int creditNet(bool Function(String code) on) => accounts
        .where((a) => on(a.code))
        .fold(0, (s, a) => s + a.credit - a.debit);
    // The write-off gives back its tax on 4457x (OD): the return of
    // compute_vat_return regularises it apart from the period's sales.
    final regularised = [
      for (final e in books.entriesOf(PostingJournal.other))
        if (e.posting.kind == PostingKind.writeOff)
          for (final l in e.lines)
            if (l.accountCode.startsWith('4457'))
              l.credit.minor - l.debit.minor,
    ].fold(0, (s, v) => s + v);
    final points = vatTaxPointLedger(
      SeededExportYear.acceptanceInvoices,
      matches: SeededExportYear.acceptanceMatches,
      instalments: {
        SeededExportYear.inv2.id: [
          TaxPointPayment(DateTime(2026, 4, 20), 12000),
        ],
      },
      basis: workspaceTaxPointBasis(_debits, 'FR'),
    ).where((a) => books.year.contains(a.on));
    // The return's taxed bases: the 0 % lines an invoice nets (a payment,
    // an expense refund) are no sale and post to no revenue account.
    final taxed = points.where((a) => a.percent > 0);
    int vatAt(double percent) => taxed
        .where((a) => a.percent == percent)
        .fold(0, (s, a) => s + a.vatCents);
    expect(
      creditNet((c) => c.startsWith('4457')) - regularised,
      taxed.fold(0, (s, a) => s + a.vatCents),
    );
    expect(creditNet((c) => c == '445711') - regularised, vatAt(20));
    expect(creditNet((c) => c == '445713'), vatAt(5.5));
    expect(
      creditNet((c) => c.startsWith('706')),
      taxed.fold(0, (s, a) => s + a.netCents),
    );
    expect(regularised, -666);
  });

  test('each report builds its rows and totals', () {
    final books = _ledger();
    for (final kind in bookReportKinds) {
      expect(reportKindById(kind), isNotNull, reason: kind);
      final data = bookReportData(kind, books, _plain)!;
      expect(data['book_rows'], isNotEmpty, reason: kind);
      expect(data['book_total_debit'], data['book_total_credit'], reason: kind);
      expect(data['book_period'], '2025-10-1 – 2026-9-30');
    }
    final trial =
        bookReportData('trial_balance', books, _plain)!['book_rows']! as List;
    expect(
      trial.map((r) => (r as Map)['label']),
      containsAll(['Grand total', 'Auxiliary balance', 'Total 411000']),
    );
  });

  test('the words default to the English ARB', () {
    const d = BookReportWords();
    final en = bookReportWordsOf(AppLocalizationsEn());
    expect(
      [
        d.total,
        d.grandTotal,
        d.auxiliary,
        d.summary,
        d.debitSide,
        d.creditSide,
        d.sales,
        d.bank,
        d.purchases,
        d.other,
      ],
      [
        en.total,
        en.grandTotal,
        en.auxiliary,
        en.summary,
        en.debitSide,
        en.creditSide,
        en.sales,
        en.bank,
        en.purchases,
        en.other,
      ],
    );
  });

  test('the default bands of each kind render the sample', () {
    final l10n = AppLocalizationsEn();
    for (final kind in bookReportKinds) {
      final report = renderReportBands(
        bands: defaultBandsForDoc(kind, l10n),
        data: sampleReportData(l10n),
      );
      final text = report!.body.whereType<ReportTableRow>().map(
        (r) => r.cells.join(' | '),
      );
      expect(text.join('\n'), contains('Total 411000'), reason: kind);
    }
  });
}
