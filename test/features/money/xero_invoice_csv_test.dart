// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2372 — Xero's sales-invoice import file: the template's header in its own
// order, the two-rate invoice as two rows under one number (pinned by the
// golden), each rate's net with its recorded VAT, 500 rows per file, the organisation's date
// order, and the refusals. Rewrite the golden with
// --dart-define=WRITE_GOLDEN=true after a deliberate change.
import 'dart:io';

import 'package:deskilo/core/vat/place_of_supply.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/xero_invoice_csv.dart';
import 'package:flutter_test/flutter_test.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');
const _golden = 'test/features/money/goldens/exports/xero_invoices.csv';

const _standard = InvoiceVatTotal(percent: 20, category: 'S', grossCents: 12000, netCents: 10000, vatCents: 2000);
const _reduced = InvoiceVatTotal(percent: 5, category: 'S', grossCents: 2100, netCents: 2000, vatCents: 100);

Invoice _invoice(
  String id, {
  List<InvoiceVatTotal> totals = const [_standard, _reduced],
  int? total,
  DateTime? voidedAt,
  InvoiceKind kind = InvoiceKind.full,
  bool due = true,
}) {
  final gross = total ?? totals.fold<int>(0, (s, t) => s + t.grossCents);
  return Invoice(
    id: id,
    workspaceId: 'ws',
    memberId: 'member-$id',
    number: 'INV-$id',
    issuedAt: DateTime(2026, 3, 4),
    dueOn: due ? DateTime(2026, 4, 3) : null,
    period: '2026-03',
    title: 'Desk and coffee',
    lines: [InvoiceLine(label: 'Desk', amountCents: gross)],
    totalCents: gross,
    currency: 'GBP',
    memberName: 'Member $id',
    memberAddress: '',
    workspaceName: 'Hub',
    workspaceAddress: '',
    issuerName: 'Owner',
    signature: '',
    vatTotals: totals,
    voidedAt: voidedAt,
    kind: kind,
    buyerParty: InvoiceParty(name: 'Studio $id Ltd', street: '1 Mill Lane', city: 'Leeds', postalCode: 'LS1 4AB', country: 'GB'),
  );
}

const _settings = XeroInvoiceSettings(
  accountCode: '200',
  taxTypes: {'20.0|S': '20% (VAT on Income)', '5.0|S': '5% (VAT on Income)'},
);

List<List<String>> _rows(String file) =>
    file.trimRight().split('\r\n').skip(1).map((l) => l.split(',')).toList();

void main() {
  test('the file opens with Xero\'s documented header, and the two-rate invoice is '
      'two rows under one number, tax-exclusive (golden)', () {
    final export = xeroInvoiceExport(invoices: [_invoice('1')], settings: _settings, zeroCategory: 'Z');
    expect(export.blockers, isEmpty);
    final file = export.files.single;
    if (_write) File(_golden).writeAsStringSync(file);
    expect(file, File(_golden).readAsStringSync());

    expect(file.split('\r\n').first, xeroInvoiceColumns.join(','));
    expect(xeroInvoiceColumns.first, '*ContactName');
    expect(xeroInvoiceColumns.last, 'BrandingTheme');
    expect(xeroInvoiceColumns.indexOf('Total'), xeroInvoiceColumns.indexOf('*DueDate') + 1);
    expect(xeroInvoiceColumns.indexOf('TaxAmount'), xeroInvoiceColumns.indexOf('*TaxType') + 1);
    final rows = _rows(file);
    final number = xeroInvoiceColumns.indexOf('*InvoiceNumber');
    final unit = xeroInvoiceColumns.indexOf('*UnitAmount');
    final tax = xeroInvoiceColumns.indexOf('*TaxType');
    expect(rows.map((r) => r[number]).toSet(), {'"INV-1"'}, reason: 'one invoice, one number');
    expect(rows.map((r) => r[unit]), ['100.00', '20.00'], reason: 'the nets, Xero adds the tax');
    expect(rows.map((r) => r[tax]), ['"20% (VAT on Income)"', '"5% (VAT on Income)"']);
    expect(rows.map((r) => r[xeroInvoiceColumns.indexOf('TaxAmount')]), ['20.00', '1.00'],
        reason: 'the VAT the invoice recorded per rate');
    expect(rows.every((r) => r.length == xeroInvoiceColumns.length), isTrue);
  });

  test('voided invoices and settlements are not sales; credit notes are '
      'named, not written', () {
    final export = xeroInvoiceExport(
      invoices: [
        _invoice('1'),
        _invoice('2', voidedAt: DateTime(2026, 3, 5)),
        _invoice('3', kind: InvoiceKind.settlement),
        _invoice('4', totals: const [], total: -1200),
      ],
      settings: _settings,
      zeroCategory: 'Z',
    );
    final numbers = _rows(export.files.single).map((r) => r[xeroInvoiceColumns.indexOf('*InvoiceNumber')]).toSet();
    expect(numbers, {'"INV-1"'});
    expect(export.creditNotes, ['INV-4']);
  });

  test('a missing sales account or tax rate refuses the file and names what '
      'is missing', () {
    final noAccount = xeroInvoiceExport(
      invoices: [_invoice('1')],
      settings: const XeroInvoiceSettings(accountCode: ' ', taxTypes: {'20.0|S': 'a', '5.0|S': 'b'}),
      zeroCategory: 'Z',
    );
    expect(noAccount.files, isEmpty);
    expect(noAccount.blockers, {const XeroInvoiceBlocker(XeroInvoiceBlock.accountCode, '')});

    final noRate = xeroInvoiceExport(
      invoices: [_invoice('1')],
      settings: const XeroInvoiceSettings(accountCode: '200', taxTypes: {'20.0|S': 'a'}),
      zeroCategory: 'Z',
    );
    expect(noRate.files, isEmpty);
    expect(noRate.blockers, {const XeroInvoiceBlocker(XeroInvoiceBlock.taxType, '5 % S')});
  });

  test('the rates to name are the documents\' own, once each', () {
    final rates = xeroRatesOf([_invoice('1'), _invoice('2', totals: const [_standard])], zeroCategory: 'Z');
    expect(rates.map(xeroRateKey), ['20.0|S', '5.0|S']);
  });

  test('at most 500 rows per file, and an invoice never spans two', () {
    final invoices = [for (var i = 0; i < 251; i++) _invoice('$i')];
    final export = xeroInvoiceExport(invoices: invoices, settings: _settings, zeroCategory: 'Z');
    expect(export.files, hasLength(2));
    expect(_rows(export.files.first), hasLength(xeroInvoiceRowsPerFile));
    expect(_rows(export.files.last), hasLength(2));
    for (final f in export.files) {
      expect(f.split('\r\n').first, xeroInvoiceColumns.join(','), reason: 'every file carries the header');
    }
  });

  test('dates follow the organisation\'s order', () {
    final day = xeroInvoiceColumns.indexOf('*InvoiceDate');
    final due = xeroInvoiceColumns.indexOf('*DueDate');
    final dayFirst = _rows(xeroInvoiceExport(invoices: [_invoice('1')], settings: _settings, zeroCategory: 'Z').files.single);
    expect([dayFirst.first[day], dayFirst.first[due]], ['04/03/2026', '03/04/2026']);
    final monthFirst = _rows(xeroInvoiceExport(
      invoices: [_invoice('1')],
      settings: XeroInvoiceSettings(accountCode: '200', taxTypes: _settings.taxTypes, dateOrder: XeroDateOrder.monthFirst),
      zeroCategory: 'Z',
    ).files.single);
    expect([monthFirst.first[day], monthFirst.first[due]], ['03/04/2026', '04/03/2026']);
  });

  test('the import file is a file target offered where Xero organisations '
      'are, asking for the organisation\'s accounts', () {
    final target = accountingTargets.singleWhere((t) => t.id == 'xero_invoice_csv');
    expect(target.transport, AccountingTransport.file);
    expect(target.payload, AccountingPayload.documents);
    expect(target.format?.needsAccounts, isTrue, reason: 'nothing is proposed for the account or the tax rates');
    for (final country in ['GB', 'CA', 'US', ...euMemberStates]) {
      expect(formatsFor(country).map((f) => f.id), contains('xero_invoice_csv'), reason: country);
    }
    expect(formatsFor('CH').map((f) => f.id), isNot(contains('xero_invoice_csv')));
  });

  test('the recorded VAT travels per row, so Xero does not round it again '
      'from the aggregated net', () {
    // Three 0.03 lines at 20 %, each recorded with 0.01 of VAT: 0.09 net
    // and 0.03 VAT, where 20 % of 0.09 would round to 0.02.
    const tiny = InvoiceVatTotal(percent: 20, category: 'S', grossCents: 12, netCents: 9, vatCents: 3);
    final row = _rows(xeroInvoiceExport(
      invoices: [_invoice('1', totals: const [tiny])],
      settings: _settings,
      zeroCategory: 'Z',
    ).files.single).single;
    expect(row[xeroInvoiceColumns.indexOf('*UnitAmount')], '0.09');
    expect(row[xeroInvoiceColumns.indexOf('TaxAmount')], '0.03');
  });

  test('an invoice without a due date leaves the column blank; Xero applies '
      'the contact\'s terms', () {
    final row = _rows(xeroInvoiceExport(invoices: [_invoice('1', due: false)], settings: _settings, zeroCategory: 'Z')
        .files.single).first;
    expect(row[xeroInvoiceColumns.indexOf('*DueDate')], '');
    expect(row[xeroInvoiceColumns.indexOf('*InvoiceDate')], '04/03/2026');
  });
}
