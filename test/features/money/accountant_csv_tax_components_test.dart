// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that the CSV states every tax of the period in its own column, and the JSON of the frozen components beside them
//
// #2361 / #2378 — the accountant CSV carries the taxes an invoice is made
// of: a Quebec invoice its GST and QST, an Ontario one its HST, a Texas
// one its state and local sales tax, a UK one its VAT at 20 % and at 5 %;
// each column sums to its components, and `tax_components` holds them as
// frozen at issue.
import 'dart:convert';

import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accountant_handoff.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_components.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String number,
  String currency,
  List<InvoiceVatTotal> totals,
) => Invoice(
  id: number,
  workspaceId: 'w',
  memberId: 'm',
  number: number,
  issuedAt: DateTime(2026, 9, 30),
  title: '2026-09',
  lines: [
    for (final t in totals)
      InvoiceLine(label: 'Desk', amountCents: t.grossCents, vatPercent: t.percent),
  ],
  totalCents: totals.fold(0, (sum, t) => sum + t.grossCents),
  currency: currency,
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'I',
  signature: 's',
  vatTotals: totals,
);

/// A total of [net] at [percent], split by [country]'s components.
InvoiceVatTotal _total(double percent, int net, int vat, {String country = ''}) =>
    InvoiceVatTotal(
      percent: percent,
      category: 'S',
      grossCents: net + vat,
      netCents: net,
      vatCents: vat,
      components:
          country.isEmpty ? const [] : vatComponentsOf(country, percent, net, vat),
    );

/// A Texas total: the state's 6.25 % and a city's 2 % of [net].
InvoiceVatTotal _texas(int net) {
  final state = (net * 625 / 10000).round();
  final local = (net * 2 / 100).round();
  return InvoiceVatTotal(
    percent: 8.25,
    category: 'S',
    grossCents: net + state + local,
    netCents: net,
    vatCents: state + local,
    state: 'TX',
    jurisdiction: '78701',
    components: [
      VatComponent(scheme: 'SALES_TAX', authority: 'US-TX', level: 'state', name: 'Texas', percent: 6.25, baseCents: net, taxCents: state),
      VatComponent(scheme: 'SALES_TAX', authority: 'US-TX', level: 'city', name: 'Austin', percent: 2, baseCents: net, taxCents: local),
    ],
  );
}

String _csv(List<Invoice> invoices) => buildAccountantCsv(
  invoices: invoices,
  matches: const {},
  generatedAt: DateTime(2026, 10),
  workspaceName: 'W',
);

/// The header and the data rows, cells unquoted.
({List<String> header, List<Map<String, String>> rows}) _read(String csv) {
  final lines = csv.trim().split('\n').where((l) => !l.startsWith('#')).toList();
  final header = lines.first.split(',');
  return (
    header: header,
    rows: [
      for (final line in lines.skip(1))
        Map.fromIterables(header, _cells(line)),
    ],
  );
}

List<String> _cells(String line) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted && ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
      cell.write('"');
      i++;
    } else if (ch == '"') {
      quoted = !quoted;
    } else if (ch == ',' && !quoted) {
      cells.add(cell.toString());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  return cells..add(cell.toString());
}

int _cents(String text) => (double.parse(text) * 100).round();

/// The sum of column [key] over the rows.
int _sum(List<Map<String, String>> rows, String key) =>
    rows.fold(0, (sum, r) => sum + _cents(r[key]!));

/// The sum of the frozen components of every row whose key is [key].
int _components(List<Map<String, String>> rows, String key) => rows.fold(
  0,
  (sum, r) =>
      sum +
      (jsonDecode(r['tax_components']!) as List)
          .cast<Map<String, Object?>>()
          .where((c) => c['key'] == key)
          .fold(0, (a, c) => a + (c['tax_cents']! as int)),
);

void main() {
  test('Quebec: GST and QST columns sum to the two components', () {
    final csv = _read(_csv([
      _invoice('F-1', 'CAD', [_total(14.975, 100000, 14975, country: 'CA')]),
      _invoice('F-2', 'CAD', [_total(14.975, 33333, 4992, country: 'CA')]),
    ]));
    expect(csv.header, containsAllInOrder(['tax_components', 'GST', 'QST']));
    expect(csv.header, isNot(contains('HST')));
    expect(_sum(csv.rows, 'GST'), _components(csv.rows, 'GST'));
    expect(_sum(csv.rows, 'QST'), _components(csv.rows, 'QST'));
    expect(_sum(csv.rows, 'GST') + _sum(csv.rows, 'QST'), 14975 + 4992);
    expect(csv.rows.first['GST'], '50.00');
    expect(csv.rows.first['QST'], '99.75');
    expect(csv.rows.first['vat_rates'], 'GST 5% + QST 9.975%');
  });

  test('Ontario: the HST in its own column', () {
    final csv = _read(_csv([
      _invoice('F-3', 'CAD', [_total(13, 100000, 13000, country: 'CA')]),
    ]));
    final keys = csv.header.skip(accountantCsvColumns.length).toList();
    expect(keys, hasLength(1));
    expect(_sum(csv.rows, keys.single), 13000);
  });

  test('Texas: state_tax and local_tax sum to the two components', () {
    final csv = _read(_csv([
      _invoice('T-1', 'USD', [_texas(10000)]),
      _invoice('T-2', 'USD', [_texas(4999)]),
    ]));
    expect(csv.header, containsAllInOrder(['state_tax', 'local_tax']));
    expect(_sum(csv.rows, 'state_tax'), 625 + 312);
    expect(_sum(csv.rows, 'local_tax'), 200 + 100);
    expect(_sum(csv.rows, 'state_tax'), _components(csv.rows, 'state_tax'));
    expect(_sum(csv.rows, 'local_tax'), _components(csv.rows, 'local_tax'));
    final frozen = (jsonDecode(csv.rows.first['tax_components']!) as List).first as Map;
    expect(frozen['authority'], 'US-TX');
    expect(frozen['level'], 'state');
    expect(frozen['jurisdiction'], '78701');
  });

  test('United Kingdom: VAT 20 and VAT 5, each its own column', () {
    final csv = _read(_csv([
      _invoice('U-1', 'GBP', [_total(20, 10000, 2000), _total(5, 4000, 200)]),
      _invoice('U-2', 'GBP', [_total(20, 500, 100)]),
    ]));
    expect(csv.header, containsAllInOrder(['VAT 20', 'VAT 5']));
    expect(_sum(csv.rows, 'VAT 20'), 2100);
    expect(_sum(csv.rows, 'VAT 5'), 200);
    expect(csv.rows.last['VAT 5'], '0.00');
    final frozen = (jsonDecode(csv.rows.first['tax_components']!) as List).first as Map;
    // A total stored without components is not presented as a split.
    expect(frozen['split'], isFalse);
    expect(frozen['tax_cents'], 2000);
  });

  test('a zero-rated total adds no column; its component stays in the JSON', () {
    const zero = InvoiceVatTotal(
      percent: 0,
      category: 'Z',
      grossCents: 1000,
      netCents: 1000,
      vatCents: 0,
    );
    final csv = _read(_csv([_invoice('Z-1', 'GBP', [zero])]));
    expect(csv.header, accountantCsvColumns);
    final frozen = (jsonDecode(csv.rows.single['tax_components']!) as List).single as Map;
    expect(frozen['category'], 'Z');
  });

  test('a scheme cannot inject into the header', () {
    expect(
      accountantTaxKey(
        _total(5, 100, 5),
        const VatComponent(scheme: '=cmd,"x"', authority: 'CA', percent: 5, baseCents: 100, taxCents: 5),
      ),
      '_cmd__x_',
    );
  });

  test('the handoff report quotes the columns the file has', () {
    final invoices = [
      _invoice('F-1', 'CAD', [_total(14.975, 100000, 14975, country: 'CA')]),
    ];
    final csv = _csv(invoices);
    final report = buildAccountantHandoff(
      invoices: invoices,
      matches: const {},
      csv: csv,
      generatedAt: DateTime.utc(2026),
    );
    expect(report.columns, [...accountantCsvColumns, 'GST', 'QST']);
    expect(report.toJson()['format_version'], 3);
  });
}
