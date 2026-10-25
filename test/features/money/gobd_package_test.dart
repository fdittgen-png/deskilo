// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The GoBD data handover (Z3) of the seeded year (gobd_package.dart): its
// index.xml is valid against the published DTD of 1 August 2002 (the copy in
// test/fixtures/gobd, which the package ships verbatim), every CSV the
// package holds is a described table and every row has the columns its
// table declares, the invoices join their lines, tax amounts and payments
// by declared keys and every key resolves, the figures add up to the
// documents', every invoice has a voucher whose e-invoice XML is extractable
// and names it, and the Verfahrensdokumentation states the live schema
// version, the number sequences and the retention clocks. The files are
// read back here, not compared with the builder's own strings.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/gobd_dtd.dart';
import 'package:deskilo/features/money/domain/gobd_package.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/presentation/gobd_procedure_document.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xml/xml.dart';

import 'support/dtd_validator.dart';
import 'support/seeded_export_year.dart';

final _de = lookupAppLocalizations(const Locale('de'));
final _from = DateTime(2026);
final _to = DateTime(2026, 12, 31);

final _sequences = [
  for (final j in ['invoice', 'credit_note', 'member'])
    NumberSequence.defaultsFor(j),
];

String _procedure(AppLocalizations l10n) => buildGobdProcedureDocument(l10n, (
  workspace: 'Cowork',
  country: 'DE',
  reference: ActiveTaxReference.current,
  from: _from,
  to: _to,
  generatedAt: DateTime(2027, 1, 5),
  fiscalYearStart: null,
  serverSchema: 591,
  sequences: _sequences,
));

Map<String, List<int>> _package() {
  final invoices = SeededExportYear.acceptanceInvoices;
  final words = reportStringsOf(_de);
  return buildGobdPackage(
    GobdRequest(
      supplierName: 'Cowork',
      supplierLocation: 'Leopoldstraße 1, 80802 München',
      from: _from,
      to: _to,
      invoices: invoices,
      matches: SeededExportYear.acceptanceMatches,
      instalments: {
        SeededExportYear.inv2.id: [
          TaxPointPayment(DateTime(2026, 4, 20), 12000),
        ],
      },
      ledger: SeededExportYear.ledger,
      purchases: [
        (
          id: 'B-1',
          kind: 'bill',
          currency: 'EUR',
          dated: DateTime(2026, 3, 10),
          lines: const [
            (
              lineNo: 1,
              grossCents: 12000,
              netCents: 10000,
              taxCents: 2000,
              recognitionKind: 'expense',
            ),
          ],
        ),
      ],
      memberNames: const {'m1': 'Ana'},
      sequences: _sequences,
      auditEvents: buildAuditEvents(
        invoices: invoices,
        matches: SeededExportYear.acceptanceMatches,
        ledger: SeededExportYear.ledger,
      ),
      taxRates: [
        for (final row in ActiveTaxReference.current.where(TaxDomain.rate))
          if (row.country == 'DE') row,
      ],
      vouchers: {
        for (final i in invoices)
          i.id: {
            'belege/${i.id}.xml': utf8.encode(
              buildInvoiceCii(
                EInvoiceInput(
                  invoice: i,
                  seller: seededCompany,
                  buyer: const InvoiceParty(name: 'Ana', country: 'FR'),
                  lineText: (line) => invoiceLineText(words, line),
                ),
              ),
            ),
          },
      },
      procedure: {gobdProcedureFileName: utf8.encode(_procedure(_de))},
    ),
  );
}

/// A table as the index declares it.
typedef _Table = ({
  String url,
  List<String> columns,
  int keys,
  List<(List<String>, String)> joins,
});

List<_Table> _tables(String index) => [
  for (final t in XmlDocument.parse(index).findAllElements('Table'))
    (
      url: t.getElement('URL')!.innerText,
      columns: [
        for (final c in t.getElement('VariableLength')!.childElements)
          if (c.name.local == 'VariablePrimaryKey' ||
              c.name.local == 'VariableColumn')
            c.getElement('Name')!.innerText,
      ],
      keys: t.findAllElements('VariablePrimaryKey').length,
      joins: [
        for (final f in t.findAllElements('ForeignKey'))
          (
            [for (final n in f.findElements('Name')) n.innerText],
            f.getElement('References')!.innerText,
          ),
      ],
    ),
];

/// The rows of a described CSV: `;`-separated, `"` around text with its
/// quotes doubled, CRLF after every record.
List<List<String>> _rows(List<int> bytes) {
  final text = utf8.decode(bytes);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ';') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      cell.write(c);
    }
  }
  expect(cell.isEmpty && row.isEmpty, isTrue, reason: 'CRLF after the last');
  return rows;
}

void main() {
  setUpAll(initializeDateFormatting);
  setUp(() => WorkspaceTime.install('Europe/Berlin'));
  tearDown(WorkspaceTime.reset);

  final fixture = File('test/fixtures/gobd/gdpdu-01-08-2002.dtd');

  test('the package ships the published DTD verbatim', () {
    expect(gobdDtd, fixture.readAsStringSync().replaceAll('\r\n', '\n'));
  });

  test('index.xml is valid against gdpdu-01-08-2002.dtd and names it', () {
    final files = _package();
    final index = utf8.decode(files['index.xml']!);
    expect(index, contains('<!DOCTYPE DataSet SYSTEM "gdpdu-01-08-2002.dtd">'));
    expect(files[gobdDtdFileName], utf8.encode(gobdDtd));
    expect(dtdViolations(fixture.readAsStringSync(), index), isEmpty);
  });

  test('the validator refuses an index the DTD forbids', () {
    final index = utf8.decode(_package()['index.xml']!);
    final broken = index.replaceFirst('<UTF8/>', '<UTF8/><UTF8/>');
    expect(dtdViolations(fixture.readAsStringSync(), broken), isNotEmpty);
    expect(
      dtdViolations(
        fixture.readAsStringSync(),
        index.replaceFirst('<Version>1.0</Version>', ''),
      ),
      isNotEmpty,
    );
  });

  test('it says what it is: the sub-ledger, not the complete books', () {
    final index = XmlDocument.parse(utf8.decode(_package()['index.xml']!));
    expect(
      index.findAllElements('Comment').single.innerText,
      contains('Nicht die vollständige Finanzbuchhaltung'),
    );
  });

  test('every CSV is a described table and every row has its columns', () {
    final files = _package();
    final tables = _tables(utf8.decode(files['index.xml']!));
    expect(
      {
        for (final p in files.keys)
          if (p.endsWith('.csv')) p,
      },
      {for (final t in tables) t.url},
    );
    for (final t in tables) {
      for (final row in _rows(files[t.url]!)) {
        expect(row, hasLength(t.columns.length), reason: '${t.url}: $row');
      }
    }
  });

  test('the invoices join their lines, tax amounts and payments by '
      'declared keys, and every key resolves', () {
    final files = _package();
    final tables = {
      for (final t in _tables(utf8.decode(files['index.xml']!)))
        t.url.replaceAll('.csv', ''): t,
    };
    for (final child in [
      'rechnungspositionen',
      'steuerbetraege',
      'zahlungen',
    ]) {
      expect(
        [for (final (c, t) in tables[child]!.joins) '${c.join(',')}->$t'],
        ['rechnung_id->rechnungen'],
      );
    }
    // Each table's key, as values, and each join's values resolve.
    Set<String> keysOf(String table) {
      final t = tables[table]!;
      return {for (final r in _rows(files[t.url]!)) r.take(t.keys).join('|')};
    }

    for (final t in tables.values) {
      // A key is unique.
      final rows = _rows(files[t.url]!);
      expect(
        keysOf(t.url.replaceAll('.csv', '')),
        hasLength(rows.length),
        reason: t.url,
      );
      for (final (columns, target) in t.joins) {
        final targetKeys = keysOf(target);
        for (final r in rows) {
          final value = [for (final c in columns) r[t.columns.indexOf(c)]]
              .join('|');
          expect(targetKeys, contains(value), reason: '${t.url} -> $target');
        }
      }
    }
    expect(_rows(files['rechnungspositionen.csv']!), isNotEmpty);
    expect(_rows(files['zahlungen.csv']!), isNotEmpty);
  });

  test('the figures are the documents\'', () {
    final files = _package();
    int cents(String s) => int.parse(s.replaceAll(',', ''));
    final invoices = _rows(files['rechnungen.csv']!);
    final lines = _rows(files['rechnungspositionen.csv']!);
    for (final i in SeededExportYear.acceptanceInvoices) {
      final row = invoices.singleWhere((r) => r[0] == i.id);
      expect((row[1], cents(row[11])), (i.number, i.totalCents));
      final sum = lines
          .where((l) => l[0] == i.id)
          .fold<int>(0, (a, l) => a + cents(l[4]));
      expect(sum, i.lines.fold<int>(0, (a, l) => a + l.amountCents));
    }
    final writeOff = _rows(files['abschreibungen.csv']!).single;
    expect((writeOff[0], writeOff[2]), (SeededExportYear.inv3.id, '40,00'));
  });

  test('every invoice has a voucher whose e-invoice is extractable and '
      'names it', () {
    final files = _package();
    final listed = _rows(files['belege.csv']!);
    for (final i in SeededExportYear.acceptanceInvoices) {
      final path = listed.singleWhere((r) => r[0] == i.id)[1];
      final xml = XmlDocument.parse(utf8.decode(files[path]!));
      expect(
        xml.descendantElements
            .where((e) => e.name.local == 'ID')
            .map((e) => e.innerText),
        contains(i.number),
        reason: path,
      );
    }
  });

  test('the Verfahrensdokumentation states the live schema version, the '
      'number sequences and the retention clocks', () {
    final doc = utf8.decode(_package()[gobdProcedureFileName]!);
    expect(doc, contains('Version 591'));
    for (final s in _sequences) {
      expect(doc, contains('«${s.prefix}»'));
    }
    // The DE clocks of the reference: invoices 8 years, books 10,
    // correspondence 6, each from the end of the fiscal year.
    for (final (label, years) in [
      (_de.retentionClassInvoice, 8),
      (_de.retentionClassBooks, 10),
      (_de.retentionClassCorrespondence, 6),
    ]) {
      expect(doc, contains('- $label: ${_de.retentionFromYearEnd(years)}'));
    }
    expect(doc, contains('Abgabenordnung'));
    final en = _procedure(lookupAppLocalizations(const Locale('en')));
    expect(en, contains('Database schema version of this installation: 591'));
  });
}
