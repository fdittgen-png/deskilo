// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — golden files per format for ONE seeded year: INV-1 at 20 % and
// 5.5 %, INV-2 part-paid, INV-3 paid in part and written off, CN-1 a credit
// note refunded to the member, INV-4/INV-5 regrouped by the settlement S-1
// and paid through it, and B-1 a supplier bill with recoverable input VAT
// (support/seeded_export_year.dart, `acceptance*`).
//
// Every file is exported the way the export run writes it: the books come
// from ONE `AccountingExportSource.read` per format (the year's
// `accounting_source_snapshot_v1` answer, and for a posted format of a
// local book its one `compute_postings` read, here the Dart twin the server
// is held to), then the format's builder writes the bytes. The bytes are
// compared with the committed files under goldens/seeded_year/. Beside the
// bytes, what the acceptance names is asserted on the files themselves:
// DATEV starts with its UTF-8 BOM and the FEC has none; the posted FEC is
// balanced per EcritureNum and letters with a DateLet; DATEV books each
// rate to its automatic account under SKR03 and SKR04; Sage writes the
// credit note as SC; the year's output VAT equals the collected-VAT lines
// (4457x) of the books, the write-off's regularisation apart.
//
// The archive's invoice PDFs need a rendering context and are not written
// here; its text members are.
//
// Regenerate ONLY when a file is meant to change, and review the diff:
//
//   UPDATE_GOLDEN=1 flutter test test/features/money/seeded_year_goldens_test.dart
//
// (`--dart-define=WRITE_GOLDEN=true` works too, as in the other money
// goldens.)
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/accounting_export_source.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/archive_fec.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/datev_package.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/fec_import_contract.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_purchases.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/sage_documents.dart';
import 'package:deskilo/features/money/domain/sage_postings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/presentation/datev_profile.dart';
import 'package:deskilo/features/money/presentation/posting_kind_labels.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/money/presentation/vat_report_actions.dart';
import 'package:deskilo/features/money/presentation/vat_tax_point_labels.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

final _update =
    Platform.environment['UPDATE_GOLDEN'] == '1' ||
    const bool.fromEnvironment('WRITE_GOLDEN');
const _dir = 'test/features/money/goldens/seeded_year';
const _ws = 'ws';
const _site = 'site';
const _year = 2026;

/// The French workspace of the year: VAT due on the debits, as the
/// posting engine's pgTAP year (242) states it.
const _invoiceLegal = {'seller_country': 'FR', 'vat_exigibility': 'invoice'};

final _generatedAt = DateTime.utc(2027, 1, 5, 9, 7, 3);
final _l10n = lookupAppLocalizations(const Locale('en'));
final _words = reportStringsOf(_l10n);
String _lineText(InvoiceLine line) => invoiceLineText(_words, line);

final _localBook = BookProfile(
  id: 'p',
  workspaceId: _ws,
  issuerSiteId: _site,
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  // #2376 — the seeded fiscal year starts on 1 October: the year's
  // documents (March to August 2026) close on 30 September 2026.
  fiscalYearStartMonth: 10,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2025, 10),
  revision: 1,
);

/// The issuer's chart: the French PCG accounts the suggested chart maps.
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

/// 5.5 % in its rate group's own account, as the suggested chart does.
final _reducedGroup = ActiveTaxReference.current.groupOfRate('FR', 5.5, 'S');

List<BookAccount> _accounts() => [
  for (final (_, _, code, type, name) in [
    ..._chart,
    (
      BookRole.vatOutput,
      _reducedGroup,
      '445713',
      AccountType.liability,
      'TVA 5,5 %',
    ),
  ])
    BookAccount(
      id: 'acc-$code',
      workspaceId: _ws,
      issuerSiteId: _site,
      code: code,
      name: name,
      type: type,
      isPosting: true,
      origin: AccountOrigin.manual,
      revision: 1,
    ),
];

List<BookMapping> _mappings() => [
  for (final (role, qualifier, code, _, _) in [
    ..._chart,
    (BookRole.vatOutput, _reducedGroup, '445713', AccountType.liability, ''),
  ])
    BookMapping(
      id: '${role.wire}:$qualifier',
      workspaceId: _ws,
      issuerSiteId: _site,
      role: role,
      qualifier: qualifier,
      accountId: 'acc-$code',
      effectiveFrom: DateTime(2020),
      revision: 1,
    ),
];

/// The member's number, as `members.member_number` writes it.
const _memberNumber = 'M-0001';

/// The year's one source answer, as the server cuts it on the workspace
/// calendar: the 2024 expense credit and the 2025 repartition are not in
/// it.
class _Snapshot implements AccountingSourceQueries {
  _Snapshot({required this.local});
  final bool local;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async => AccountingSourceSnapshot.demo(
    invoices: [
      for (final i in SeededExportYear.acceptanceInvoices)
        (id: i.id, number: i.number, totalCents: i.totalCents),
    ],
    ledger: [
      for (final e in SeededExportYear.ledger)
        if (e.createdAt.year == year) e,
    ],
    repartitions: const [],
    bookProfiles: local ? [_localBook] : const [],
    matches: SeededExportYear.acceptanceMatches,
    instalments: {
      SeededExportYear.inv2.id: [TaxPointPayment(DateTime(2026, 4, 20), 12000)],
    },
  );
}

/// The local book: `compute_postings` answered by its Dart twin over the
/// same documents (the demo repository's composition), its chart and the
/// documents' member.
class _Books implements BookProfileRepository {
  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    final book = PostingBook(
      accounts: _accounts(),
      mappings: _mappings(),
      issuerSiteId: issuerSiteId,
    );
    bool inPeriod(DateTime day) => !day.isBefore(from) && !day.isAfter(to);
    final sold = postingsOf(
      invoices: [
        for (final i in SeededExportYear.acceptanceInvoices)
          if (inPeriod(i.issuedAt)) i,
      ],
      matches: SeededExportYear.acceptanceMatches,
      book: book,
      groupOf: (t) =>
          ActiveTaxReference.current.groupOfRate('FR', t.percent, t.category),
    );
    // #3031 — B-2 is in Swiss francs: booked in euros at its recorded
    // rate, as `compute_postings` books it.
    final bought = purchasePostingsOf(
      purchases: [SeededExportYear.supplierBill, SeededExportYear.francBill],
      book: book,
      groupOf: (percent) =>
          ActiveTaxReference.current.groupOfRate('FR', percent, 'S'),
      functional: 'EUR',
      rates: {SeededExportYear.francBill.summary.id: SeededExportYear.francRate},
    );
    return PostingSet(
      [
        ...sold.postings,
        for (final p in bought)
          if (inPeriod(p.date)) p,
      ]..sort(comparePostings),
      book.blockers,
    );
  }

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async =>
      (accounts: _accounts(), mappings: _mappings());

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async => {
    for (final i in SeededExportYear.acceptanceInvoices)
      if (documentIds.contains(i.id))
        i.id: PostingParty(
          kind: 'member',
          number: _memberNumber,
          name: i.memberName,
        ),
    // #2376 — the supplier of B-1, by its supplier number.
    if (documentIds.contains(SeededExportYear.supplierBill.summary.id))
      SeededExportYear.supplierBill.summary.id: const PostingParty(
        kind: 'supplier',
        number: '17',
        name: 'Nettoyage Pézenas',
      ),
    if (documentIds.contains(SeededExportYear.francBill.summary.id))
      SeededExportYear.francBill.summary.id: const PostingParty(
        kind: 'supplier',
        number: '23',
        name: 'Logiciels Léman SA',
      ),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('an export called ${invocation.memberName}');
}

/// The one read of [formatId]'s export, as the run makes it, from
/// [invoices] (the list the person holds; the seeded year by default).
Future<AccountingExportInput> _read(
  String formatId, {
  bool local = false,
  String country = 'FR',
  List<Invoice>? invoices,
}) async {
  final input =
      await AccountingExportSource(
        _Snapshot(local: local),
        () => GenericJournalExport(_Books()),
      ).read(
        formatId: formatId,
        workspaceId: _ws,
        country: country,
        year: _year,
        invoices: invoices ?? SeededExportYear.acceptanceInvoices,
      );
  expect(input, isNotNull, reason: '$formatId: the source was refused');
  return input!;
}

/// The tax points of the exported year, on the workspace's basis.
List<VatTaxPointAmount> _taxPoints(AccountingExportInput input) =>
    vatTaxPointLedger(
      input.books.invoices,
      matches: input.books.matches,
      instalments: input.books.instalments,
      basis: workspaceTaxPointBasis(_invoiceLegal, 'FR'),
    );

/// The posted FEC's file, as the run saves it.
String _postedFec(AccountingExportInput input) =>
    switch (postedFecOf(_posted(input))) {
      JournalFile(:final content) => content,
      final other => fail('expected the FEC, got $other'),
    };

JournalPosted _posted(AccountingExportInput input) => switch (input.posted) {
  final JournalPosted p => p,
  final other => fail('expected the postings, got $other'),
};

String _fec(AccountingExportInput input) {
  final b = input.books;
  return buildFecFile(
    FecRequest(
      invoices: b.invoices,
      matches: b.matches,
      company: seededCompany,
      accounts: const FecAccounts(),
      lineText: _lineText,
      customersLabel: _l10n.fecAccountCustomers,
      revenueLabel: _l10n.fecAccountRevenue,
      bankLabel: _l10n.fecAccountBank,
      vatLabel: _l10n.fecAccountVat,
      ledger: b.ledger,
      memberNames: const {'m1': 'Ana'},
      repartitions: b.repartitions,
      expensesLabel: _l10n.fecAccountExpenses,
      taxPoints: _taxPoints(input),
      vatPendingLabel: vatWords(_l10n).fecAccountVatPending,
    ),
  );
}

/// The German rate of each French one of the seeded year: DATEV derives
/// the tax from the account, and only a German rate has an automatic
/// account (19 % to 8400/4400, 7 % to 8300/4300).
final _germanRate = {20.0: 19.0, 5.5: 7.0};

/// [i] at German rates: the same gross, its net and tax at the new rate.
Invoice _atGermanRates(Invoice i) => i.copyWith(
  lines: [
    for (final l in i.lines)
      l.copyWith(vatPercent: _germanRate[l.vatPercent] ?? l.vatPercent),
  ],
  vatTotals: [
    for (final t in i.vatTotals)
      () {
        final rate = _germanRate[t.percent] ?? t.percent;
        final net = (t.grossCents * 100 / (100 + rate)).round();
        return InvoiceVatTotal(
          percent: rate,
          category: t.category,
          grossCents: t.grossCents,
          netCents: net,
          vatCents: t.grossCents - net,
        );
      }(),
  ],
);

/// The Buchungsstapel of the seeded year's DATEV export on SKR03 or
/// [chart], one after the other, each with its BOM and header.
Future<String> _datev(String? chart) async {
  final package = await _datevPackage(chart);
  return [
    for (final MapEntry(:key, :value) in package.files.entries)
      if (key.startsWith('EXTF_Buchungsstapel_')) value,
  ].join();
}

/// #2375 — the DATEV export of the seeded year at German rates as the run
/// writes it: a Buchungsstapel per month and journal, the member's Debitor
/// from their number (M-0001, frozen on none of the documents, so the
/// number the member holds today), KOST1, the voucher links, the first
/// half-year closed, and the Stammdaten.
Future<DatevPackage> _datevPackage(String? chart) async {
  final input = await _read(
    'datev',
    country: 'DE',
    invoices: [
      for (final i in SeededExportYear.acceptanceInvoices) _atGermanRates(i),
    ],
  );
  final b = input.books;
  return buildDatevPackage(
    DatevPackageRequest(
      request: DatevRequest(
        invoices: b.invoices,
        matches: b.matches,
        accounts: datevAccountsFor(
          b.bookProfiles,
          DatevAccounts(chart: chart),
          _year,
        ),
        from: DateTime(_year),
        to: DateTime(_year, 12, 31),
        generatedAt: _generatedAt,
        consultantNumber: '1234567',
        clientNumber: '54321',
        detail: const DatevDetail(defaultCostCentre: 'Cowork', voucherLinks: true),
        ledger: b.ledger,
        repartitions: b.repartitions,
        batchName: 'Cowork',
        taxPoints: _taxPoints(input),
      ),
      bookProfiles: b.bookProfiles,
      closed: (from, to) => !to.isAfter(DateTime(_year, 6, 30)),
      memberSequence: NumberSequence.defaultsFor('member'),
      debtorBase: 10000,
      memberNumbers: const {'m1': _memberNumber},
      memberNames: const {'m1': 'Ana'},
    ),
  );
}

String _safT(
  AccountingExportInput input, {
  required bool portugal,
  SafTLedgerAccounts? accounts,
  List<Posting>? posted,
}) => buildSafTFile(
  SafTRequest(
    invoices: input.books.invoices,
    matches: input.books.matches,
    company: seededCompany,
    currency: 'EUR',
    softwareVersion: safTSoftwareVersion,
    createdAt: _generatedAt,
    lineText: _lineText,
    fallbackDescription: _l10n.invoicesTitle,
    profile: portugal ? SafTProfile.portugal : SafTProfile.generic,
    ledgerAccounts: accounts,
    bookPostings: posted,
  ),
);

/// The archive's text members (its invoice PDFs need a rendering context).
Future<Map<String, String>> _bundle({required bool local}) async {
  final input = await _read('bundle', local: local);
  final b = input.books;
  final files = <String, List<int>>{
    'register.csv': textBytes(
      buildInvoiceRegisterCsv(
        b.invoices,
        integrity: {for (final i in b.invoices) i.id: 'ok'},
      ),
    ),
    'audit-trail.csv': textBytes(
      buildAuditTrailCsv(
        events: buildAuditEvents(
          invoices: b.invoices,
          matches: b.matches,
          ledger: b.ledger,
        ),
        generatedAt: _generatedAt,
        workspaceName: 'Cowork',
        source: b.revisions,
      ),
    ),
  };
  final fec = local
      ? (postedFecOf(_posted(input)) as JournalFile).content
      : _fec(input);
  final year = local ? _posted(input).year : FiscalYear.calendar(_year);
  final plan =
      archiveFecPlan(
            fec: fec,
            fileName: fecFileName(seededCompany.legalId, year.to),
            year: year,
            closed: true,
            exports: const [],
            contract: checkFecImportContract(
              textBytes(fec),
              year: year,
              thirdPartyAccounts: local
                  ? thirdPartyAccountsOf(_posted(input))
                  : {const FecAccounts().customers},
            ),
          )
          as ArchiveFecWrite;
  addArchiveFec(files, 'FR', plan.members);
  return {
    for (final MapEntry(:key, :value) in withRetentionNotice(
      files,
      'FR',
      _year,
    ).entries)
      // The FEC under its own name is the golden `fec.txt`.
      (key.contains('FEC') ? 'fec.txt' : key): utf8.decode(value),
  };
}

/// Every golden, by file name, written through its format's one read.
final Map<String, Future<String> Function()> _files = {
  'fec.txt': () async => _fec(await _read('fec')),
  'fec_local_book.txt': () async => _postedFec(await _read('fec', local: true)),
  'sage50.csv': () async {
    final b = (await _read('sage50', country: 'GB')).books;
    final trail = sageRowsOfInvoices(
      invoices: b.invoices,
      matches: b.matches,
      accounts: const SageAccounts(),
      customers: const SageCustomers(
        memberNumbers: {'m1': _memberNumber},
        sellerCountry: 'FR',
      ),
      baseCurrency: 'EUR',
      groupOf: (t) =>
          ActiveTaxReference.current.groupOfRate('FR', t.percent, t.category),
    );
    expect(trail.blockers, isEmpty);
    return sageFile(trail.rows);
  },
  // #2373 — a local book's audit trail, from its one postings read.
  'sage50_local_book.csv': () async {
    final journal = _posted(await _read('sage50', local: true, country: 'GB'));
    final trail = sageRowsOfPostings(
      journal.postings,
      book: (
        accounts: const SageAccounts(),
        customers: const SageCustomers(memberNumbers: {}, sellerCountry: 'FR'),
        baseCurrency: journal.functionalCurrency!,
      ),
      parties: journal.parties,
      documents: {for (final i in SeededExportYear.acceptanceInvoices) i.id: i},
      kindText: (kind) => postingKindLabel(_l10n, kind),
    );
    expect(trail.blockers, isEmpty);
    return sageFile(trail.rows);
  },
  'saft_pt.xml': () async =>
      _safT(await _read('saft_pt', country: 'PT'), portugal: true),
  'saft.xml': () async {
    const fec = FecAccounts();
    return _safT(
      await _read('saft'),
      portugal: false,
      accounts: SafTLedgerAccounts(
        customers: fec.customers,
        revenue: fec.revenue,
        bank: fec.bank,
        vat: fec.vat,
        writeOff: fec.writeOff,
      ),
    );
  },
  'saft_local_book.xml': () async {
    final input = await _read('saft', local: true);
    return _safT(input, portugal: false, posted: _posted(input).postings);
  },
  'accountant.csv': () async {
    final b = (await _read('accountant_csv')).books;
    return buildAccountantCsv(
      invoices: b.invoices,
      matches: b.matches,
      generatedAt: _generatedAt,
      workspaceName: 'Cowork',
    );
  },
  'generic_journal.csv': () async =>
      journalCsvOf(_posted(await _read('generic_journal_csv', local: true))),
  'audit_trail.csv': () async {
    final b = (await _read('audit_trail')).books;
    return buildAuditTrailCsv(
      events: buildAuditEvents(
        invoices: b.invoices,
        matches: b.matches,
        ledger: b.ledger,
      ),
      generatedAt: _generatedAt,
      workspaceName: 'Cowork',
      source: b.revisions,
    );
  },
  'fr_ereporting.xml': () async {
    final b = (await _read('fr_ereporting')).books;
    // The month of the latest invoice, as the run reports it.
    final last = SeededExportYear.acceptanceInvoices
        .map((i) => i.issuedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final month = WorkspaceTime.dateOf(last);
    return frEReport(
      b.invoices,
      start: DateTime(month.year, month.month),
      end: DateTime(month.year, month.month + 1, 0),
      matches: b.matches,
      instalments: b.instalments,
      onReceipts: workspaceTaxPointBasis(_invoiceLegal, 'FR').onReceipts,
    ).toXml();
  },
  for (final name in [
    'register.csv',
    'audit-trail.csv',
    'fec.txt',
    'fec-manifest.txt',
    'retention.txt',
  ])
    'bundle/$name': () async => (await _bundle(local: false))[name]!,
};

int _cents(String s) =>
    s.isEmpty ? 0 : (double.parse(s.replaceAll(',', '.')) * 100).round();

/// The FEC's rows as maps keyed by its header.
List<Map<String, String>> _fecRows(String file) {
  final lines = file.split('\r\n').where((l) => l.isNotEmpty).toList();
  final head = lines.first.split('\t');
  return [
    for (final l in lines.skip(1)) Map.fromIterables(head, l.split('\t')),
  ];
}

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('every format the registry offers has a golden here', () {
    // The formats; the archive is its text members.
    final covered = {
      for (final name in _files.keys)
        if (name.startsWith('bundle/'))
          'bundle'
        else
          name.split(RegExp(r'[._]')).first,
      // DATEV's goldens are its export's files, compared below.
      'datev',
    };
    expect(
      covered,
      containsAll([
        'fec',
        'datev',
        'sage50',
        // The Swiss journal's goldens are its Swiss year's
        // (swiss_kmu_test.dart): it posts on a Swiss chart.
        'saft',
        'accountant',
        'generic',
        'audit',
        'fr',
        'bundle',
      ]),
    );
  });

  for (final MapEntry(key: name, value: build) in _files.entries) {
    test('$name is byte-identical to its golden', () async {
      final file = File('$_dir/$name');
      // Bytes, not a decoded string: a decoder drops DATEV's BOM.
      final bytes = utf8.encode(await build());
      if (_update) {
        file
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
      }
      expect(
        file.existsSync(),
        isTrue,
        reason: '$name has no golden: UPDATE_GOLDEN=1 writes it',
      );
      expect(bytes, file.readAsBytesSync(), reason: name);
    });
  }

  // #2375 — the export's files are its goldens: the same names, the same
  // bytes. A file added or gone is a difference too.
  for (final (chart, dir) in [(null, 'datev_skr03'), ('SKR04', 'datev_skr04')]) {
    test('the DATEV export ($dir) is byte-identical to its goldens', () async {
      final package = await _datevPackage(chart);
      expect(package.problems, isEmpty);
      final folder = Directory('$_dir/$dir');
      if (_update) {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
        folder.createSync(recursive: true);
        for (final MapEntry(:key, :value) in package.files.entries) {
          File('${folder.path}/$key').writeAsBytesSync(utf8.encode(value));
        }
      }
      expect(
        {for (final f in folder.listSync().whereType<File>()) f.uri.pathSegments.last},
        package.files.keys.toSet(),
        reason: '$dir: UPDATE_GOLDEN=1 writes the files',
      );
      for (final MapEntry(:key, :value) in package.files.entries) {
        expect(
          utf8.encode(value),
          File('${folder.path}/$key').readAsBytesSync(),
          reason: '$dir/$key',
        );
      }
    });
  }

  test('DATEV starts with the UTF-8 BOM; no FEC carries one', () async {
    const bom = [0xEF, 0xBB, 0xBF];
    for (final chart in [null, 'SKR04']) {
      expect(utf8.encode(await _datev(chart)).take(3), bom);
    }
    for (final name in ['fec.txt', 'fec_local_book.txt', 'bundle/fec.txt']) {
      final first = utf8.encode(await _files[name]!()).take(3).toList();
      expect(first, isNot(bom), reason: name);
      expect(utf8.decode(first).startsWith('Jou'), isTrue, reason: name);
    }
  });

  test('the posted FEC balances per EcritureNum and letters with a '
      'DateLet', () async {
    final rows = _fecRows(await _files['fec_local_book.txt']!());
    final byEntry = <String, int>{};
    for (final r in rows) {
      byEntry[r['EcritureNum']!] =
          (byEntry[r['EcritureNum']!] ?? 0) +
          _cents(r['Debit']!) -
          _cents(r['Credit']!);
      expect(
        r['EcritureLet']!.isEmpty,
        r['DateLet']!.isEmpty,
        reason: 'EcritureLet and DateLet go together (${r['EcritureNum']})',
      );
    }
    expect(byEntry.values.toSet(), {0});
    expect(rows.where((r) => r['EcritureLet']!.isNotEmpty), isNotEmpty);
    // The supplier bill is booked with its deductible VAT.
    expect(rows.map((r) => r['CompteNum']), containsAll(['401000', '445660']));
  });

  test(
    'DATEV books each rate to its automatic account, SKR03 and SKR04',
    () async {
      List<String> revenue(String file) => [
        for (final l in file.split('\r\n').skip(2).where((l) => l.isNotEmpty))
          ...l.split(';').sublist(6, 8),
      ];
      expect(revenue(await _datev(null)), containsAll(['8400', '8300']));
      expect(revenue(await _datev('SKR04')), containsAll(['4400', '4300']));
    },
  );

  // A refunded credit note's match holds the amount paid OUT, positive
  // (0436): the posted books pay it back to the member, as the
  // document-based files do (DATEV `Erstattung`, Sage SP). 9999 /
  // `_settled` (posting_rules.dart); before them it posted as a receipt.
  test('the posted books pay a refunded credit note OUT', () async {
    final postings = _posted(await _read('generic_journal_csv', local: true))
        .postings
        .where((p) => p.documentNumber == 'CN-1')
        .toList();
    expect(postings.map((p) => p.kind), [
      PostingKind.creditNote,
      PostingKind.refund,
    ]);
    final rows = _fecRows(await _files['fec_local_book.txt']!())
        .where((r) => r['EcritureNum'] == 'BQ-CN-1')
        .toList();
    final byAccount = {for (final r in rows) r['CompteNum']!: r};
    expect(_cents(byAccount['411000']!['Debit']!), 5000);
    expect(_cents(byAccount['512000']!['Credit']!), 5000);
    expect(_cents(byAccount['411000']!['Credit']!), 0);
  });

  test('the document-based files pay the refund out', () async {
    final datev = (await _datev(null)).split('\r\n');
    expect(
      datev.where((l) => l.contains('"Erstattung CN-1"')).single.split(';'),
      containsAllInOrder(['50,00', '"S"', '10001', '1200']),
    );
  });

  test('Sage writes the credit note as SC', () async {
    final rows = (await _files['sage50.csv']!()).split('\r\n');
    expect(rows.where((r) => r.startsWith('SC,')), isNotEmpty);
  });

  // #2373 — a local book's Sage 50 file is its postings, read once: SC for
  // CN-1, SP for its refund, PI at T1 for B-1, JD/JC for INV-3's write-off,
  // SI at T1 and T5 on the two-rate INV-1, 18 columns, every Account
  // Reference a number of at most eight characters.
  test('the local book\'s Sage 50 file books every event of the year', () async {
    final rows = [
      for (final r in (await _files['sage50_local_book.csv']!()).split('\r\n').skip(1))
        if (r.isNotEmpty) r.split(','),
    ];
    List<String> types(String number) => [
      for (final r in rows)
        if (r[5] == '"$number"') r[0],
    ];
    expect(rows.every((r) => r.length == sageColumns.length), isTrue);
    expect(types('CN-1'), ['SC', 'SP']);
    expect(types('INV-3'), containsAllInOrder(['SI', 'SR', 'JD', 'JD', 'JC']));
    final bill = rows.where((r) => r[5] == '"B-1"' && r[0] == 'PI').single;
    expect(bill[8], const SageAccounts().taxCode);
    expect(
      [for (final r in rows) if (r[5] == '"INV-1"' && r[0] == 'SI') r[8]],
      [const SageAccounts().taxCode, SageAccounts.reducedCode],
    );
    for (final r in rows) {
      final account = r[1].replaceAll('"', '');
      expect(account.length, lessThanOrEqualTo(8));
      expect(account, isNot(contains('-')));
    }
  });

  test('the year\'s output VAT equals the books\' collected-VAT lines, the '
      'write-off\'s regularisation apart', () async {
    final input = await _read('generic_journal_csv', local: true);
    final postings = _posted(input).postings;
    var collected = 0;
    var regularised = 0;
    for (final p in postings) {
      for (final l in p.lines) {
        if (l.role != BookRole.vatOutput) continue;
        final net = l.credit.minor - l.debit.minor;
        if (p.kind == PostingKind.writeOff) {
          regularised += net;
        } else {
          collected += net;
        }
      }
    }
    final due = _taxPoints(input)
        .where((a) => a.on.year == _year)
        .fold<int>(0, (s, a) => s + a.grossCents - a.netCents);
    expect(collected, due);
    // INV-3's open 40.00 at 20 %: 6.66 of tax given back.
    expect(regularised, -666);
  });

  // #2376 — the FEC as an import contract, over the seeded fiscal year
  // that starts on 1 October.
  test('the posted FEC covers the fiscal year and is named after its '
      'closing day', () async {
    final books = _posted(await _read('fec', local: true));
    expect(books.year, FiscalYear(DateTime(2025, 10), DateTime(2026, 9, 30)));
    expect(
      fecFileName(seededCompany.legalId, books.year.to),
      '812345678FEC20260930.txt',
    );
    for (final r in _fecRows(await _files['fec_local_book.txt']!())) {
      expect(
        r['ValidDate']!.compareTo('20260930') <= 0 &&
            r['EcritureDate']!.compareTo('20251001') >= 0,
        isTrue,
        reason: r['EcritureNum'],
      );
    }
  });

  test('every receivable and payable line names its auxiliary account',
      () async {
    final rows = _fecRows(await _files['fec_local_book.txt']!());
    final third = rows.where(
      (r) => r['CompteNum'] == '411000' || r['CompteNum'] == '401000',
    );
    expect(third, isNotEmpty);
    for (final r in third) {
      expect(
        (r['CompAuxNum'], r['CompAuxLib']!.isNotEmpty),
        (
          r['CompteNum'] == '411000'
              ? '411M0001'
              : r['PieceRef'] == 'B-2'
              ? '40123'
              : '40117',
          true,
        ),
        reason: r['EcritureNum'],
      );
    }
    // Every other line leaves the auxiliary columns empty.
    expect(
      rows
          .where((r) => !third.contains(r))
          .every((r) => r['CompAuxNum']!.isEmpty && r['CompAuxLib']!.isEmpty),
      isTrue,
    );
  });

  test('the posted and the archived FEC keep the import contract', () async {
    final books = _posted(await _read('fec', local: true));
    final report = checkFecImportContract(
      utf8.encode(await _files['fec_local_book.txt']!()),
      year: books.year,
      thirdPartyAccounts: thirdPartyAccountsOf(books),
      knownAccounts: books.accountNames.keys.toSet(),
    );
    expect(report.findings, isEmpty);
    expect(report.records, greaterThan(0));
    // The archive's manifest quotes the contract: passed for the posted
    // FEC, its open letters for the one written from the documents.
    final posted = await _bundle(local: true);
    expect(posted['fec-manifest.txt'], contains('import_contract: passed'));
    expect(posted['fec-manifest.txt'], contains('status: final'));
    expect(
      posted['fec-manifest.txt'],
      contains('file: 812345678FEC20260930.txt'),
    );
    expect(posted['fec.txt'], await _files['fec_local_book.txt']!());
    expect(
      await _files['bundle/fec-manifest.txt']!(),
      contains('import_contract: failed (lettering)'),
    );
  });

  test('a party without a client code stops the posted FEC, named', () async {
    final books = _posted(await _read('fec', local: true));
    final refused = postedFecOf(
      JournalPosted(
        books.postings,
        year: books.year,
        accountNames: books.accountNames,
        parties: {
          for (final MapEntry(:key, :value) in books.parties.entries)
            key: value.kind == 'supplier'
                ? PostingParty(kind: value.kind, number: '', name: value.name)
                : value,
        },
        functionalCurrency: 'EUR',
      ),
    );
    expect(refused, isA<JournalRefused>());
    expect((refused as JournalRefused).blockers.map((b) => b.subject).toSet(), {
      'Nettoyage Pézenas ()',
      'Logiciels Léman SA ()',
    });
  });

  // #3031 — the seeded year's Swiss-franc bill through the real export path:
  // the local book's one read, the posted FEC written from it.
  test('the CHF bill is posted in EUR at its recorded rate, with '
      'Montantdevise and Idevise', () async {
    final rows = _fecRows(await _files['fec_local_book.txt']!())
        .where((r) => r['PieceRef'] == 'B-2')
        .toList();
    expect(rows.map((r) => r['EcritureNum']).toSet(), {'HA-B-2', 'BQ-B-2'});
    for (final r in rows) {
      expect(r['Idevise'], 'CHF', reason: r['EcritureNum']);
      expect(r['Montantdevise'], isNotEmpty, reason: r['EcritureNum']);
    }
    final bill = rows.where((r) => r['EcritureNum'] == 'HA-B-2').toList();
    // 240.00 CHF × 1.0657 = 255.768 → 255.77; 12.50 × 1.0657 = 13.32;
    // the whole 252.50 × 1.0657 = 269.09 on the supplier.
    expect(
      {
        for (final r in bill)
          (r['Montantdevise'], _cents(r['Debit']!), _cents(r['Credit']!)),
      },
      {('240,00', 25577, 0), ('12,50', 1332, 0), ('252,50', 0, 26909)},
    );
    final total = bill.fold(
      0,
      (s, r) => s + _cents(r['Debit']!) - _cents(r['Credit']!),
    );
    expect(total, 0);
  });

  test('without its recorded rate the CHF bill stops the books, named', () async {
    final book = PostingBook(
      accounts: _accounts(),
      mappings: _mappings(),
      issuerSiteId: _localBook.issuerSiteId,
    );
    final out = purchasePostingsOf(
      purchases: [SeededExportYear.francBill],
      book: book,
      groupOf: (_) => 'standard',
      functional: 'EUR',
    );
    expect(out, isEmpty);
    expect(book.blockers.map((b) => (b.block, b.subject)), [
      (PostingBlock.missingRate, 'B-2 (CHF)'),
    ]);
  });
}
