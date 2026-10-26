// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2378 item 5 — the readable handover of a British, Irish, Canadian or US
// archive: the tables of the year's snapshot, written by the same table
// builder and in the same cell format as the GoBD package, without the German index and DTD, and a README that
// describes every table and every column in English (the CRA asks for
// English or French). The README is read back line by line here and held
// against the tables' own column lists, not against the builder's strings.
import 'dart:convert';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/gobd_package.dart';
import 'package:deskilo/features/money/domain/gobd_tables.dart';
import 'package:deskilo/features/money/domain/readable_handover.dart';
import 'package:deskilo/features/money/domain/records_location.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _readme = 'tables/README.txt';

/// A Canadian space on an installation its operator declared in Germany.
const _toronto = RecordsLocation(
  issuerCountry: 'CA',
  hostingCountry: 'DE',
  craReference: '',
);

GobdRequest _request() => GobdRequest(
  supplierName: 'Maple Desk Ltd',
  supplierLocation: '100 King St W, Toronto ON',
  dayOf: WorkspaceTime.dateOf,
  from: DateTime(2026),
  to: DateTime(2026, 12, 31),
  invoices: SeededExportYear.acceptanceInvoices,
  matches: SeededExportYear.acceptanceMatches,
  ledger: SeededExportYear.ledger,
  vouchers: {
    for (final i in SeededExportYear.acceptanceInvoices)
      i.id: {
        'invoices/${i.number}.pdf': const [37, 80, 68, 70],
      },
  },
);

String _text(Map<String, List<int>> files, String path) =>
    utf8.decode(files[path]!);

void main() {
  test('the archives of GB, IE, CA and US carry it, and no other', () {
    for (final c in ['GB', 'ie', 'CA', 'US']) {
      expect(archiveCarriesReadableHandover(c), isTrue, reason: c);
    }
    for (final c in ['DE', 'FR', 'CH', 'ES']) {
      expect(archiveCarriesReadableHandover(c), isFalse, reason: c);
    }
  });

  test('every table is written by the GoBD table builder, with no index and no DTD', () {
    // Built from the same request, the bytes are the GoBD package's. The
    // archive's own request differs in one table on purpose: its audit
    // trail is the archive's audit-trail.csv, with the files handed out.
    final files = readableHandoverFiles(_request(), _toronto);
    final gobd = buildGobdPackage(_request());
    final tables = gobdTables(_request());
    expect(files.keys.toSet(), {
      _readme,
      for (final t in tables) 'tables/${t.url}',
    });
    for (final t in tables) {
      expect(files['tables/${t.url}'], gobd[t.url], reason: t.url);
    }
    expect(
      files.keys.where((p) => p.endsWith('.xml') || p.endsWith('.dtd')),
      isEmpty,
    );
  });

  test('the README describes every column of every table in English', () {
    final lines = const LineSplitter().convert(
      _text(readableHandoverFiles(_request(), _toronto), _readme),
    );
    expect(
      lines.first,
      'Readable handover: Maple Desk Ltd, 2026-01-01 to 2026-12-31',
    );
    for (final t in gobdTables(_request())) {
      final heading = lines.indexWhere(
        (l) => l.startsWith('tables/${t.url}: '),
      );
      expect(heading, isNot(-1), reason: t.url);
      for (final (i, c) in t.columns.indexed) {
        final line = lines[heading + 1 + i];
        expect(
          line,
          startsWith('  ${i + 1}. ${c.name} ('),
          reason: '${t.name}.${c.name}',
        );
        expect(line.substring(line.indexOf('): ') + 3), isNotEmpty);
      }
    }
  });

  test('the README states the format and the scope', () {
    final readme = _text(readableHandoverFiles(_request(), _toronto), _readme);
    expect(readme, contains('fields separated by ";"'));
    expect(readme, contains('DD.MM.YYYY'));
    expect(readme, contains('not the complete general ledger'));
    expect(readme, contains('  1. id (text, key): Identifier of the document'));
    expect(readme, contains('  Joins kunde_id to kunden'));
  });

  test('the document files are named where the archive holds them', () {
    final belege = _text(
      readableHandoverFiles(_request(), _toronto),
      'tables/belege.csv',
    );
    final first = SeededExportYear.acceptanceInvoices.first;
    expect(belege, contains('"${first.id}";"invoices/${first.number}.pdf"'));
  });

  test('an empty year still describes every table', () {
    final files = readableHandoverFiles(
      GobdRequest(
        supplierName: 'Empty',
        supplierLocation: '',
        dayOf: WorkspaceTime.dateOf,
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
        invoices: const [],
        matches: const {},
      ),
      _toronto,
    );
    expect(files['tables/rechnungen.csv'], isEmpty);
    expect(_text(files, _readme), contains('tables/rechnungen.csv: '));
  });

  test('the README states where the records are kept, as declared', () {
    String readme(RecordsLocation location) =>
        _text(readableHandoverFiles(_request(), location), _readme);
    // A Canadian space on an installation declared in Germany: the region,
    // the rule and that no CRA authorisation is recorded.
    expect(const LineSplitter().convert(readme(_toronto)).sublist(2, 5), [
      'Records location: hosted in DE, as the operator of this '
          'installation declares it.',
      'These records are kept outside Canada (ETA s.286, ITA s.230).',
      'CRA authorisation reference: none recorded.',
    ]);
    // Its authorisation, once recorded, is quoted.
    expect(
      readme(
        const RecordsLocation(
          issuerCountry: 'CA',
          hostingCountry: 'DE',
          craReference: 'CRA-2026-0042',
        ),
      ),
      contains('CRA authorisation reference: CRA-2026-0042.'),
    );
    // Nothing declared: nothing is asserted, and a Canadian space still
    // reads that nothing places its records in Canada.
    final undeclared = readme(
      const RecordsLocation(
        issuerCountry: 'CA',
        hostingCountry: null,
        craReference: '',
      ),
    );
    expect(undeclared, contains('not declared by the operator'));
    expect(
      undeclared,
      contains('Nothing declares these records kept in Canada'),
    );
    // In Canada, or a British space: no Canadian notice.
    for (final location in const [
      RecordsLocation(
        issuerCountry: 'CA',
        hostingCountry: 'CA',
        craReference: '',
      ),
      RecordsLocation(
        issuerCountry: 'GB',
        hostingCountry: 'DE',
        craReference: '',
      ),
    ]) {
      expect(readme(location), isNot(contains('ETA s.286')));
      expect(
        readme(location),
        contains('hosted in ${location.hostingCountry}'),
      );
    }
  });
}
