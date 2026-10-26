// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2377 — the Swiss journal of a local book, written from its postings: a
// seeded Swiss year in francs (8.1 %, 3.8 % and an exempt letting on one
// invoice, 8.1 % and 2.6 % on a second one paid in part and written off, a
// credit note refunded, a supplier's bill in euros booked at its recorded
// rate) on the KMU chart as the suggested chart takes it. The year is read
// the way the export run reads it — one source snapshot and ONE postings
// read — and both layouts are compared with their committed files:
// goldens/seeded_year/ch_kmu.csv and banana_transactions.txt. Beside the
// bytes: every entry balances, each taxed row carries the MWST code and
// the Ziffer of its rate, a receivable carries its invoice's QR reference,
// Banana's header is its own column names, the bill keeps its euros. A rate
// group with no MWST code stops the file and is named; no local book, no
// journal.
//
// Regenerate ONLY when a file is meant to change, and review the diff:
//
//   UPDATE_GOLDEN=1 flutter test test/features/money/swiss_kmu_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/accounting_export_source.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/application/save_book_profile.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/swiss_kmu.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

final _update = Platform.environment['UPDATE_GOLDEN'] == '1';
const _dir = 'test/features/money/goldens/seeded_year';
const _ws = 'ws-ch';
const _site = 'site-ch';

const _seller = InvoiceParty(
  name: 'Cowork Lausanne SA',
  country: 'CH',
  legalId: 'CHE-123.456.788',
  vatRegime: 'standard',
);

InvoiceVatTotal _vt(double p, String category, int net, int vat) =>
    InvoiceVatTotal(
      percent: p,
      category: category,
      grossCents: net + vat,
      netCents: net,
      vatCents: vat,
    );

Invoice _invoice(
  String number,
  DateTime at,
  List<InvoiceVatTotal> totals, {
  String replaces = '',
}) {
  final gross = totals.fold(0, (s, t) => s + t.grossCents);
  return Invoice(
    id: 'id-$number',
    workspaceId: _ws,
    memberId: 'm1',
    number: number,
    issuedAt: at,
    period: '2026-03',
    title: 'T $number',
    lines: [
      for (final t in totals)
        InvoiceLine(
          kind: 'subscription',
          label: 'Desk',
          amountCents: t.grossCents,
          vatPercent: t.percent,
        ),
    ],
    totalCents: gross,
    currency: 'CHF',
    memberName: 'Ana',
    memberAddress: 'Rue du Bourg 1, 1003 Lausanne',
    workspaceName: 'Cowork Lausanne SA',
    workspaceAddress: 'Avenue de la Gare 1, 1003 Lausanne',
    issuerName: 'Flo',
    signature: 'f' * 64,
    sellerParty: _seller,
    vatTotals: totals,
    replacesNumber: replaces,
  );
}

/// INV-101: a desk at 8.1 %, a night at 3.8 % and an exempt letting.
final _inv101 = _invoice('INV-101', DateTime(2026, 3, 2), [
  _vt(8.1, 'S', 100000, 8100),
  _vt(3.8, 'S', 10000, 380),
  _vt(0, 'E', 50000, 0),
]);

/// INV-102: a desk at 8.1 % and drinks at 2.6 %; paid in part, the rest
/// written off.
final _inv102 = _invoice('INV-102', DateTime(2026, 4, 1), [
  _vt(8.1, 'S', 20000, 1620),
  _vt(2.6, 'S', 5000, 130),
]);

/// CN-101 on INV-101, refunded.
final _cn101 = _invoice('CN-101', DateTime(2026, 5, 4), [
  _vt(8.1, 'S', -10000, -810),
], replaces: 'INV-101');

final _invoices = [_inv101, _inv102, _cn101];

final _matches = {
  _inv101.id: InvoiceMatch(
    invoiceId: _inv101.id,
    paidCents: 168480,
    resolution: 'exact',
    matchedAt: DateTime(2026, 3, 20),
  ),
  _inv102.id: InvoiceMatch(
    invoiceId: _inv102.id,
    paidCents: 10000,
    resolution: 'writeoff',
    matchedAt: DateTime(2026, 4, 20),
    writeoffAt: DateTime(2026, 6, 30),
  ),
  _cn101.id: InvoiceMatch(
    invoiceId: _cn101.id,
    paidCents: 10810,
    resolution: 'refunded',
    matchedAt: DateTime(2026, 5, 10),
  ),
};

/// B-101: a supplier's bill of EUR 216.20 (200.00 at 8.1 %, its tax
/// recoverable), booked in francs at the rate recorded with it.
final _bill = PurchaseDetail(
  summary: PurchaseSummary(
    id: 'B-101',
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: 'software',
    reference: 'B-101',
    currency: 'EUR',
    originalDate: DateTime(2026, 5, 12),
  ),
  revision: 1,
  lines: const [
    PurchaseLine(
      lineNo: 1,
      description: 'Booking software',
      grossCents: 21620,
      netCents: 20000,
      taxCents: 1620,
      taxRatePercent: 8.1,
      recoverableTaxCents: 1620,
    ),
  ],
  sources: const [],
  obligations: [
    PurchaseObligation(
      id: 'o-B-101',
      purchaseId: 'B-101',
      creditorKind: CreditorKind.supplier,
      creditorId: 'supplier-1',
      amountCents: 21620,
      currency: 'EUR',
      appliedCents: 21620,
      remainingCents: 0,
      allocations: [
        SettlementAllocation(
          id: 'pay-B-101',
          isReversal: false,
          amountCents: 21620,
          method: 'transfer',
          reference: 'SEPA',
          paidOn: DateTime(2026, 5, 20),
        ),
      ],
    ),
  ],
);

final _rate = FxRate(
  base: 'EUR',
  quote: 'CHF',
  rate: ExactDecimal.parse('0.9312'),
  source: 'tax_authority',
  date: DateTime(2026, 5, 12),
  version: '1',
);

final _localBook = BookProfile(
  id: 'p-ch',
  workspaceId: _ws,
  issuerSiteId: _site,
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'CHF',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2026),
  revision: 1,
);

/// The QR references of the invoices, as their QR-bills on a QR-IBAN
/// carry them.
final _references = {
  for (final i in [_inv101, _inv102]) i.id: qrrReferenceOf(i.number)!,
};

/// The chart the Swiss space takes from the suggestion, as the book chart
/// sheet saves it.
late ({List<BookAccount> accounts, List<BookMapping> mappings}) _chart;

class _Snapshot implements AccountingSourceQueries {
  _Snapshot({this.local = true});
  final bool local;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async => AccountingSourceSnapshot.demo(
    invoices: [
      for (final i in _invoices)
        (id: i.id, number: i.number, totalCents: i.totalCents),
    ],
    ledger: const [],
    repartitions: const [],
    bookProfiles: local ? [_localBook] : const [],
    matches: _matches,
  );
}

/// `compute_postings` answered by its Dart twin over the Swiss year.
class _Books implements BookProfileRepository {
  int postingReads = 0;

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    postingReads++;
    final book = PostingBook(
      accounts: _chart.accounts,
      mappings: _chart.mappings,
      issuerSiteId: issuerSiteId,
    );
    final reference = ActiveTaxReference.current;
    final sold = postingsOf(
      invoices: _invoices,
      matches: _matches,
      book: book,
      groupOf: (t) => reference.groupOfRate('CH', t.percent, t.category),
    );
    final bought = purchasePostingsOf(
      purchases: [_bill],
      book: book,
      groupOf: (percent) => reference.groupOfRate('CH', percent, 'S'),
      functional: 'CHF',
      rates: {_bill.summary.id: _rate},
    );
    return PostingSet(
      [...sold.postings, ...bought]..sort(comparePostings),
      book.blockers,
    );
  }

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async => _chart;

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async => {
    for (final i in _invoices)
      i.id: const PostingParty(kind: 'member', number: 'M-0001', name: 'Ana'),
    _bill.summary.id: const PostingParty(
      kind: 'supplier',
      number: '31',
      name: 'Logiciels Léman SA',
    ),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('an export called ${invocation.memberName}');
}

Future<GenericJournal?> _read(
  String formatId, {
  _Books? books,
  bool local = true,
}) async => (await AccountingExportSource(
  _Snapshot(local: local),
  () => GenericJournalExport(books ?? _Books()),
).read(
  formatId: formatId,
  workspaceId: _ws,
  country: 'CH',
  year: 2026,
  invoices: _invoices,
))?.posted;

Future<JournalPosted> _posted([_Books? books]) async =>
    switch (await _read('ch_kmu', books: books)) {
      final JournalPosted p => p,
      final other => fail('expected the postings, got $other'),
    };

SwissJournal _journal(JournalPosted books, {TaxReferenceSet? reference}) =>
    swissJournalOf(
      books.postings,
      reference: reference ?? ActiveTaxReference.current,
      paymentReferences: _references,
      parties: books.parties,
    );

Future<List<SwissJournalRow>> _rows() async => _journal(await _posted()).rows;

void _golden(String name, String content) {
  final file = File('$_dir/$name');
  final bytes = utf8.encode(content);
  if (_update) {
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
  expect(file.existsSync(), isTrue, reason: '$name: UPDATE_GOLDEN=1 writes it');
  expect(bytes, file.readAsBytesSync(), reason: name);
}

void main() {
  setUpAll(() async {
    final repo = FakeBookProfileRepository(country: 'CH');
    final outcome = await BookProfiles(repo).adoptSuggested(
      suggestedAccounts(
        workspaceId: _ws,
        issuerSiteId: _site,
        countryCode: 'CH',
        regime: VatRegime.vatRegistered,
      ),
      effectiveFrom: DateTime.utc(2026),
      current: const [],
    );
    expect(outcome, BookSaveOutcome.saved);
    _chart = (accounts: repo.accounts, mappings: repo.mappings);
  });

  test('the KMU chart is taken mapped: each rate group on its account, '
      'one account per number', () {
    String code(String id) =>
        _chart.accounts.firstWhere((a) => a.id == id).code;
    expect(
      {
        for (final m in _chart.mappings)
          m.qualifier == null ? m.role.wire : '${m.role.wire}:${m.qualifier}':
              code(m.accountId),
      },
      {
        'customers': '1100',
        'revenue': '3400',
        'bank': '1020',
        'vat_output': '2200',
        'expenses': '6500',
        'vat_input': '1170',
        'suppliers': '2000',
        'write_off': '3805',
        'revenue:reduced': '3401',
        'revenue:intermediate': '3401',
        'revenue:exempt': '3402',
      },
    );
    final codes = _chart.accounts.map((a) => a.code).toList();
    expect(codes.toSet(), hasLength(codes.length));
    expect(
      codes,
      containsAll(['2201', '6000']),
      reason: 'offered, mapped to nothing',
    );
  });

  test('both layouts are written from ONE postings read and match their '
      'goldens', () async {
    final books = _Books();
    final journal = _journal(await _posted(books));
    expect(books.postingReads, 1);
    expect(journal.missingCodes, isEmpty);
    _golden(
      'ch_kmu.csv',
      swissJournalFile(journal.rows, SwissJournalLayout.kmu),
    );
    _golden(
      'banana_transactions.txt',
      swissJournalFile(journal.rows, SwissJournalLayout.banana),
    );
  });

  test('every entry balances, in francs', () async {
    final rows = await _rows();
    expect(rows.every((r) => r.amount.currency == 'CHF'), isTrue);
    final byEntry = <String, int>{};
    for (final r in rows) {
      expect(r.debit.isNotEmpty || r.credit.isNotEmpty, isTrue);
      // A row with both accounts balances itself; a composite entry's
      // one-sided rows balance together.
      final signed = r.debit.isNotEmpty && r.credit.isNotEmpty
          ? 0
          : r.debit.isNotEmpty
          ? r.amount.minor
          : -r.amount.minor;
      final key = '${r.document}|${r.date}';
      byEntry[key] = (byEntry[key] ?? 0) + signed;
    }
    expect(byEntry.values.toSet(), {0});
  });

  test("each taxed row carries its rate's MWST code and Ziffer", () async {
    final rows = await _rows();
    String codes(String document) => [
      for (final r in rows)
        if (r.document == document && r.vatCode.isNotEmpty)
          '${r.vatCode}/${r.ziffer}/${r.vat!.toDecimalString()}',
    ].join(' ');
    expect(codes('INV-101'), 'V81/303/81.00 V38/343/3.80');
    expect(codes('CN-101'), 'V81/303/8.10');
    expect(codes('B-101'), 'M81/400/15.09');
    expect(codes('INV-102'), startsWith('V81/303/16.20 V26/313/1.30 V81/303/'));
    final exempt = rows.singleWhere((r) => r.credit == '3402');
    expect(
      (exempt.vatCode, exempt.ziffer, exempt.amount.toDecimalString()),
      ('', '230', '500.00'),
    );
  });

  test("a receivable carries its invoice's QR reference; the bill its "
      'euros and its supplier', () async {
    final rows = await _rows();
    final inv101 = rows.where((r) => r.document == 'INV-101').toList();
    expect(inv101, isNotEmpty);
    for (final r in inv101) {
      expect(r.reference, _references[_inv101.id]);
      expect(isValidQrr(r.reference), isTrue);
    }
    expect(
      rows.where((r) => r.document == 'CN-101').map((r) => r.reference),
      everyElement(''),
      reason: 'a credit note carries no QR-bill',
    );
    final bill = rows.where((r) => r.document == 'B-101').toList();
    expect(bill.map((r) => r.party).toSet(), {'31'});
    expect(bill.first.original?.currency, 'EUR');
    expect(bill.first.original?.minor, 21620);
    expect(bill.first.amount.currency, 'CHF');
  });

  test("Banana reads its own column names, tab separated, ISO dates", () async {
    final file = swissJournalFile(await _rows(), SwissJournalLayout.banana);
    final lines = file.trimRight().split('\r\n');
    expect(
      lines.first,
      'Date\tDoc\tDescription\tAccountDebit\tAccountCredit\tAmount\tVatCode',
    );
    expect(lines.skip(1).every((l) => l.split('\t').length == 7), isTrue);
    expect(lines[1], startsWith('2026-03-02\tINV-101\t'));
    expect(file.codeUnitAt(0), isNot(0xFEFF));
  });

  test('the journal is a BOM, `;` and CRLF file; the same books give the '
      'same bytes', () async {
    final a = swissJournalFile(await _rows(), SwissJournalLayout.kmu);
    final b = swissJournalFile(await _rows(), SwissJournalLayout.kmu);
    expect(a, b);
    expect(
      a,
      startsWith('\u{FEFF}Datum;Beleg;Referenz;Text;Soll;Haben;Betrag;'),
    );
    expect(a, endsWith('\r\n'));
  });

  test('a rate group with no MWST code stops the file and is named', () async {
    final without = TaxReferenceSet([
      for (final r in ActiveTaxReference.current.rows)
        if (r.key != 'ch_kmu/tax:reduced' && r.key != 'ch_kmu/input:standard')
          r,
    ]);
    expect(_journal(await _posted(), reference: without).missingCodes, [
      'input:standard',
      'tax:reduced',
    ]);
  });

  test('no local book, no journal; an unmapped role is named', () async {
    expect(
      await _read('banana_transactions', local: false),
      isA<JournalNeedsLocalBook>(),
    );
    final saved = _chart;
    _chart = (
      accounts: saved.accounts,
      mappings: [
        for (final m in saved.mappings)
          if (m.role != BookRole.writeOff) m,
      ],
    );
    try {
      final read = await _read('ch_kmu');
      expect(read, isA<JournalBlocked>());
      expect((read! as JournalBlocked).roles, ['write_off']);
    } finally {
      _chart = saved;
    }
  });
}
