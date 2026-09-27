// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1640 — the accountant CSV stays inert in a spreadsheet, and the
// handoff report beside it counts what the file actually holds. The
// expected totals below are written out by hand and the bytes are read
// back with this file's OWN parser, so neither check trusts the exporter
// under test.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accountant_handoff.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _inv({
  required String id,
  String? number,
  String currency = 'EUR',
  int charges = 12000,
  int net = 10000,
  int vat = 2000,
  DateTime? issuedAt,
  DateTime? voidedAt,
  String memberName = 'Alex Sample',
  String title = 'Coworking March',
  InvoiceKind kind = InvoiceKind.full,
}) => Invoice(
  id: id,
  workspaceId: 'ws',
  memberId: 'm-1',
  number: number ?? 'INV-$id',
  issuedAt: issuedAt ?? DateTime.utc(2026, 3, 14, 9),
  title: title,
  lines: [InvoiceLine(label: 'Desk', amountCents: charges)],
  totalCents: charges,
  currency: currency,
  memberName: memberName,
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: '',
  voidedAt: voidedAt,
  kind: kind,
  vatTotals: vat == 0 && net == charges
      ? const []
      : [
          InvoiceVatTotal(
            percent: 20,
            category: 'S',
            grossCents: charges,
            netCents: net,
            vatCents: vat,
          ),
        ],
);

InvoiceMatch _paid(String id, int minor, {String status = 'confirmed'}) =>
    InvoiceMatch(
      invoiceId: id,
      paidCents: minor,
      resolution: 'paid',
      status: status,
      matchedAt: DateTime.utc(2026, 4, 2),
      note: '',
    );

/// This test's own reader: a regular expression over each line, not the
/// character loop the product uses.
List<List<String>> _cells(String csv) {
  final field = RegExp(r'(?:^|,)(?:"((?:[^"]|"")*)"|([^,]*))');
  return [
    for (final line in csv.split('\n').skip(1))
      if (line.isNotEmpty && !line.startsWith('#'))
        [
          for (final m in field.allMatches(line))
            m.group(1)?.replaceAll('""', '"') ?? m.group(2) ?? '',
        ],
  ].skip(1).toList();
}

({String csv, AccountantHandoff report}) _export(
  List<Invoice> invoices, [
  Map<String, InvoiceMatch> matches = const {},
  String workspaceName = 'Pézenas',
]) {
  final at = DateTime.utc(2026, 5, 1, 8);
  final csv = buildAccountantCsv(
    invoices: invoices,
    matches: matches,
    generatedAt: at,
    workspaceName: workspaceName,
  );
  return (
    csv: csv,
    report: buildAccountantHandoff(
      invoices: invoices,
      matches: matches,
      csv: csv,
      generatedAt: at,
    ),
  );
}

void main() {
  group('text stays text in a spreadsheet', () {
    test('formula starters are neutralised, numbers are not', () {
      final out = _export([
        _inv(
          id: '1',
          memberName: '=HYPERLINK("http://x","y")',
          title: '+1+1',
          charges: -1200,
          net: -1000,
          vat: -200,
        ),
        _inv(id: '2', memberName: '@SUM(A1)', title: '-2'),
      ]);
      final rows = _cells(out.csv);
      expect(rows[0][3], "'=HYPERLINK(\"http://x\",\"y\")");
      expect(rows[0][5], "'+1+1");
      expect(rows[1][3], "'@SUM(A1)");
      expect(rows[1][5], "'-2");
      // A credit note's amounts stay signed numbers.
      expect(rows[0][7], '-10.00');
      expect(rows[0][8], '-2.00');
    });

    test('control characters and delimiters cannot open a cell', () {
      final out = _export(
        [_inv(id: '1', memberName: 'A\tB\r\n=cmd', title: 'x,"y";z')],
        const {},
        'Evil, =1+1\n"quoted";more',
      );
      final rows = _cells(out.csv);
      expect(rows.single.length, accountantCsvColumns.length);
      expect(rows.single[3], 'A B =cmd');
      expect(rows.single[5], 'x,"y";z');
      final preamble = out.csv.split('\n').first;
      expect(preamble.startsWith('# DesKilo accounting export'), isTrue);
      expect(preamble, isNot(contains(',')));
      expect(preamble, isNot(contains('"')));
    });

    test('very long text is bounded, Unicode kept', () {
      final out = _export([_inv(id: '1', memberName: 'é' * 5000)]);
      final name = _cells(out.csv).single[3];
      expect(name.length, accountantCsvMaxText);
      expect(name.endsWith('…'), isTrue);
    });
  });

  group('the report counts what the file holds', () {
    test('totals per currency and lifecycle, from hand-written sums', () {
      final out = _export(
        [
          _inv(id: '1'),
          _inv(id: '2', voidedAt: DateTime.utc(2026, 3, 20)),
          _inv(id: '3', currency: 'JPY', charges: 1200, net: 1000, vat: 200),
          _inv(id: '4', currency: 'KWD', charges: 12345, net: 10288, vat: 2057),
          _inv(id: '5', kind: InvoiceKind.settlement),
        ],
        {'1': _paid('1', 12000)},
      );
      final r = out.report;
      expect(r.included, 4);
      expect(r.csvRows, 4);
      expect(r.excluded, {'settlement_summary': 1});
      expect(r.totals['EUR']!['issued']!.grossMinor, 12000);
      expect(r.totals['EUR']!['voided']!.grossMinor, 12000);
      expect(r.totals['JPY']!['issued']!.vatMinor, 200);
      expect(r.totals['KWD']!['issued']!.netMinor, 10288);
      expect(r.totals.keys, unorderedEquals(['EUR', 'JPY', 'KWD']));
      expect(r.payments['EUR']!.confirmedMinor, 12000);
      expect(r.clean, isTrue);
      final rows = _cells(out.csv);
      expect(rows.firstWhere((c) => c[6] == 'JPY')[9], '1200');
      expect(rows.firstWhere((c) => c[6] == 'KWD')[9], '12.345');
      expect(out.csv, contains('# 4 invoice(s)'));
    });

    test('pending and confirmed payments stay apart', () {
      final r = _export(
        [_inv(id: '1'), _inv(id: '2')],
        {'1': _paid('1', 5000), '2': _paid('2', 7000, status: 'pending')},
      ).report;
      expect(r.payments['EUR']!.confirmedMinor, 5000);
      expect(r.payments['EUR']!.pendingMinor, 7000);
      expect(r.payments['EUR']!.pendingCount, 1);
    });

    test('tied timestamps give the same bytes whatever the input order', () {
      final a = _inv(id: '1', number: 'INV-B');
      final b = _inv(id: '2', number: 'INV-A');
      final one = _export([a, b]);
      final two = _export([b, a]);
      expect(one.csv, two.csv);
      expect(one.report.csvSha256, two.report.csvSha256);
      expect(
        one.report.csvSha256,
        sha256.convert(utf8.encode(one.csv)).toString(),
      );
      expect(_cells(one.csv).map((c) => c[0]), ['INV-A', 'INV-B']);
    });

    test('a missing currency, a duplicate, a foreign match block the file', () {
      final r = _export(
        [_inv(id: '1', currency: ''), _inv(id: '2'), _inv(id: '2')],
        {'x': _paid('x', 100), '2': _paid('other', 100)},
      ).report;
      final kinds = r.findings.map((f) => f.kind).toSet();
      expect(
        kinds,
        containsAll([
          HandoffFindingKind.missingCurrency,
          HandoffFindingKind.duplicateDocument,
          HandoffFindingKind.orphanMatch,
        ]),
      );
      expect(r.clean, isFalse);
    });

    test('an overpayment is shown, not blocking', () {
      final r = _export([_inv(id: '1')], {'1': _paid('1', 20000)}).report;
      expect(r.findings.single.kind, HandoffFindingKind.overpaid);
      expect(r.clean, isTrue);
    });

    test('a file that is not the counted documents is caught', () {
      final invoices = [_inv(id: '1'), _inv(id: '2')];
      final csv = buildAccountantCsv(
        invoices: invoices.take(1).toList(),
        matches: const {},
        generatedAt: DateTime.utc(2026),
        workspaceName: 'W',
      );
      final r = buildAccountantHandoff(
        invoices: invoices,
        matches: const {},
        csv: csv,
        generatedAt: DateTime.utc(2026),
      );
      expect(
        r.findings.map((f) => f.kind),
        contains(HandoffFindingKind.rowCountMismatch),
      );
    });

    test('the manifest names format, columns and the file hash', () {
      final out = _export([_inv(id: '1')]);
      final json = jsonDecode(out.report.toPrettyJson()) as Map;
      expect(json['format_version'], accountantCsvFormatVersion);
      expect(json['columns'], accountantCsvColumns);
      expect((json['file'] as Map)['sha256'], out.report.csvSha256);
      expect(json['clean'], isTrue);
    });
  });
}
