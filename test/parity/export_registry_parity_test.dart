// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3330 (of #3328) -- PR B of the parity baseline: what the accounting export
// offers and reads, captured before the dispatch moves into contributions.
//
//  * the registry: for every country, the targets in the order the sheet lists
//    them and, for a file target, its format id, claim, extension and the three
//    flags that decide what is asked or said (accounts, registration number,
//    uncertified software);
//  * the source requirement of every format id as `AccountingExportSource`
//    resolves it today: whether the format is written from the posting engine
//    (cloud book / local book), how many fiscal years the archive reads and how
//    many `compute_postings` reads it costs;
//  * the byte goldens already exist per format -- `goldens/seeded_year/` (one
//    seeded year, the DATEV UTF-8 BOM and the BOM-less FEC asserted on the
//    files) and `goldens/exports/` -- and are not copied. This file pins that
//    every registry format has one, or is listed here with the reason it has
//    none, so a format cannot join the registry without bytes under test.
//
// Rewrite only with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/accounting_export_source.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _dir = 'test/parity/golden/exports';

const _countries = [
  'AT',
  'BE',
  'CA',
  'CH',
  'DE',
  'DK',
  'ES',
  'FR',
  'GB',
  'IT',
  'LU',
  'NL',
  'NO',
  'PT',
  'RO',
  'US',
  '',
];

const _ws = 'parity-workspace';

final _localBook = BookProfile(
  id: 'p',
  workspaceId: _ws,
  issuerSiteId: 'parity-site',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime.utc(2020),
  revision: 1,
);

class _Source implements AccountingSourceQueries {
  _Source({required this.local});
  final bool local;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async => AccountingSourceSnapshot.demo(
    invoices: const [],
    ledger: const [],
    repartitions: const [],
    bookProfiles: local ? [_localBook] : const [],
  );
}

/// Counts the postings reads a format costs.
class _Books implements BookProfileRepository {
  int reads = 0;

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    reads++;
    return const PostingSet([], []);
  }

  @override
  Future<List<BookProfile>> fetchBookProfiles(String workspaceId) async => [
    _localBook,
  ];

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async =>
      (accounts: const <BookAccount>[], mappings: const <BookMapping>[]);

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every format id of the registry, once, in registry order.
List<AccountingFormat> _registryFormats() {
  final seen = <String>{};
  return [
    for (final t in accountingTargets)
      if (t.format case final f? when seen.add(f.id)) f,
  ];
}

/// The formats with no byte golden and why: listed so a new format cannot
/// join the registry unnoticed.
const _noBytes = <String, String>{
  'saft_no':
      'SAF-T Financial: written from the posting engine; its bytes are '
      'pinned by the SAF-T files of saf_t_financial_test',
  'saft_dk': 'SAF-T Financial: as saft_no',
  'saft_ro': 'SAF-T Financial: as saft_no',
  'saft_at': 'SAF-T Financial: as saft_no',
  'faia_lu': 'FAIA: as saft_no',
  'saft_oecd_full': 'SAF-T Financial: as saft_no',
  'gobd': 'a package of tables and a DTD: pinned by gobd_package_test',
  'general_ledger': 'a printed book report (PDF)',
  'trial_balance': 'a printed book report (PDF)',
  'journals': 'a printed book report (PDF)',
  'xero_invoice_csv': 'exports/xero_invoices.csv in export_bytes_golden_test',
};

bool _hasBytes(String id) {
  const names = {
    'fec': ['seeded_year/fec.txt', 'exports/fec.txt'],
    'datev': ['seeded_year/datev_skr03', 'exports/datev.csv'],
    'sage50': ['seeded_year/sage50.csv', 'exports/sage.csv'],
    'saft': ['seeded_year/saft.xml', 'exports/saf_t.xml'],
    'saft_pt': ['seeded_year/saft_pt.xml'],
    'ch_kmu': ['seeded_year/ch_kmu.csv'],
    'banana_transactions': ['seeded_year/banana_transactions.txt'],
    'business_central_journal_xlsx': ['seeded_year/bc_journal.txt'],
    'sage50_ca': ['sage50_ca_journal.txt'],
    'accountant_csv': ['seeded_year/accountant.csv', 'exports/accountant.csv'],
    'audit_trail': ['seeded_year/audit_trail.csv', 'exports/audit_trail.csv'],
    'bundle': ['seeded_year/bundle'],
    'fr_ereporting': ['seeded_year/fr_ereporting.xml'],
    'generic_journal_csv': ['seeded_year/generic_journal.csv'],
  };
  final held = names[id];
  if (held == null) return false;
  return held.any(
    (p) =>
        FileSystemEntity.typeSync('test/features/money/goldens/$p') !=
        FileSystemEntityType.notFound,
  );
}

void main() {
  test('the export registry, the source each format reads and the bytes that '
      'pin it are what they were', () async {
    final registry = StringBuffer();
    for (final c in _countries) {
      registry.writeln('## ${c.isEmpty ? '(none)' : c}');
      for (final t in targetsFor(c, reference: ActiveTaxReference.current)) {
        final f = t.format;
        registry.writeln(
          f == null
              ? '${t.id} | -'
              : '${t.id} | ${f.id} | ${f.claim.name} | ${f.extension} | '
                    'accounts=${f.needsAccounts} legalId=${f.needsLegalId} '
                    'uncertified=${f.uncertifiedSoftware}',
        );
      }
    }

    final source = StringBuffer(
      'format | country | book | posted | archiveYears | postingsReads\n',
    );
    for (final f in _registryFormats()) {
      for (final country in const ['FR', 'DE']) {
        for (final local in const [false, true]) {
          final books = _Books();
          final input =
              await AccountingExportSource(
                _Source(local: local),
                () => GenericJournalExport(books),
              ).read(
                formatId: f.id,
                workspaceId: _ws,
                country: country,
                year: 2026,
                invoices: const [],
              );
          source.writeln(
            '${f.id} | $country | ${local ? 'local' : 'cloud'} | '
            '${input == null ? 'refused' : (input.posted != null ? 'yes' : 'no')} | '
            '${input?.archiveYears.length ?? '-'} | ${books.reads}',
          );
        }
      }
    }

    final coverage = StringBuffer();
    for (final f in _registryFormats()) {
      coverage.writeln(
        '${f.id} | ${_hasBytes(f.id) ? 'bytes' : (_noBytes[f.id] ?? 'MISSING')}',
      );
    }
    expect(
      coverage.toString(),
      isNot(contains('MISSING')),
      reason: 'a registry format with no byte golden and no reason',
    );

    expectParity(
      dir: _dir,
      text: {
        'registry.txt': registry.toString(),
        'source_requirements.golden': source.toString(),
        'byte_coverage.txt': coverage.toString(),
      },
    );
  });

  // The byte-level promises the exports already make, read from the committed
  // seeded-year goldens (not from the code that may move): DATEV starts with
  // its UTF-8 BOM, no FEC carries one, and a file that states what an invoice
  // charges states `chargesCents` (22550 for INV-1), never the balance after
  // its payments and credits (`totalCents`, 15550).
  test('the byte invariants of the committed goldens hold', () {
    const root = 'test/features/money/goldens/seeded_year';
    const bom = [0xEF, 0xBB, 0xBF];
    for (final chart in ['datev_skr03', 'datev_skr04']) {
      final files = Directory('$root/$chart')
          .listSync()
          .whereType<File>()
          .toList();
      expect(files, isNotEmpty, reason: chart);
      for (final f in files) {
        expect(f.readAsBytesSync().take(3).toList(), bom, reason: f.path);
      }
    }
    for (final name in ['fec.txt', 'fec_local_book.txt', 'bundle/fec.txt']) {
      expect(
        File('$root/$name').readAsBytesSync().take(3).toList(),
        isNot(bom),
        reason: '$name: the FEC has no BOM',
      );
    }
    final inv1 = File('$root/accountant.csv')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('"INV-1"'));
    expect(
      inv1,
      contains(',200.00,25.50,225.50,'),
      reason: 'the accountant file states what INV-1 charges (chargesCents)',
    );
    expect(
      inv1,
      isNot(contains(',25.50,155.50,')),
      reason:
          'the gross is what was charged, not the balance (totalCents); '
          'that appears only in the paid column',
    );
  });
}
