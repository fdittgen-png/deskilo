// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4269 -- a monthly invoice whose netted credits exceed its charges has a
// negative total and is still a sale: its charges are the sale (revenue and
// VAT against the receivable), its netted credits are their own lines (money
// that had already arrived), and the credit left to the member is paid back as
// money out. Written the same way in the FEC and in DATEV, balanced, with no
// negative amount, and byte for byte as the committed goldens
// (`UPDATE_GOLDEN=1 flutter test test/features/money/mixed_document_books_test.dart`
// rewrites them when the document is MEANT to change). A real credit note,
// whose positions are all reversals, is written as before.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/accounting_journals.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/presentation/datev_profile.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _dir = 'test/features/money/goldens/mixed_document';
final _update = Platform.environment['UPDATE_GOLDEN'] == '1';
final _l10n = lookupAppLocalizations(const Locale('fr'));
final _words = reportStringsOf(_l10n, formatLocale: null);
String _lineText(InvoiceLine line) => invoiceLineText(_words, line);

/// 120.00 charged at [rate] % (net 100.00 + its VAT) and 240.00 of payments
/// already received: a total of -120.00 (-121.00 at 19 %).
Invoice _mixed(double rate) {
  final vat = (10000 * rate / 100).round();
  final gross = 10000 + vat;
  return Invoice(
    id: 'id-F-1',
    workspaceId: 'ws',
    memberId: 'm1',
    number: 'F-1',
    issuedAt: DateTime(2026, 7, 15),
    period: '2026-07',
    title: 'T F-1',
    lines: [
      InvoiceLine(kind: 'subscription', label: '100', amountCents: gross, vatPercent: rate),
      const InvoiceLine(kind: 'payment', label: 'virement', amountCents: -20000),
      const InvoiceLine(kind: 'payment', label: 'carte', amountCents: -4000),
    ],
    totalCents: gross - 24000,
    currency: 'EUR',
    memberName: 'Ana',
    memberAddress: 'a',
    workspaceName: 'w',
    workspaceAddress: 'a',
    issuerName: 'Flo',
    signature: 'f' * 64,
    sellerParty: seededCompany,
    vatTotals: [
      InvoiceVatTotal(percent: rate, category: 'S', grossCents: gross, netCents: 10000, vatCents: vat),
    ],
  );
}

/// The member was paid back what the invoice left them.
Map<String, InvoiceMatch> _refund(Invoice i) => {
  i.id: InvoiceMatch(
    invoiceId: i.id,
    paidCents: -i.totalCents,
    resolution: 'refunded',
    matchedAt: DateTime(2026, 7, 20),
  ),
};

String _fec(Invoice i, Map<String, InvoiceMatch> matches) => buildFecFile(
  FecRequest(
    dayOf: WorkspaceTime.dateOf,
    currency: 'EUR',
    invoices: [i],
    matches: matches,
    company: seededCompany,
    accounts: FecAccounts(reference: ActiveTaxReference.current, chartCountry: 'FR', journals: accountingJournalsOf(const {})),
    lineText: _lineText,
    customersLabel: _l10n.fecAccountCustomers,
    revenueLabel: _l10n.fecAccountRevenue,
    bankLabel: _l10n.bookRoleBank,
    vatLabel: _l10n.fecAccountVat,
    memberNames: const {'m1': 'Ana'},
    expensesLabel: _l10n.fecAccountExpenses,
    vatPendingLabel: 'TVA en attente',
    reference: ActiveTaxReference.current,
  ),
);

DatevPackage _datev(Invoice i, Map<String, InvoiceMatch> matches) => buildDatevPackage(
  DatevPackageRequest(
    request: DatevRequest(
      currency: 'EUR',
      invoices: [i],
      matches: matches,
      accounts: datevAccountsFor(
        const [],
        DatevAccounts(reference: ActiveTaxReference.current, chartCountry: 'DE'),
        2026,
      ),
      from: DateTime(2026),
      to: DateTime(2026, 12, 31),
      generatedAt: DateTime.utc(2027, 1, 5, 9, 7, 3),
      consultantNumber: '1234567',
      clientNumber: '54321',
      detail: const DatevDetail(defaultCostCentre: 'Cowork', voucherLinks: false),
      batchName: 'Cowork',
      dayOf: WorkspaceTime.dateOf,
    ),
    bookProfiles: const [],
    closed: (from, to) => false,
    memberSequence: NumberSequence.defaultsFor('member'),
    debtorBase: 10000,
    memberNumbers: const {'m1': 'M-0001'},
    memberNames: const {'m1': 'Ana'},
  ),
);

void _golden(String name, String text) {
  final file = File('$_dir/$name');
  final bytes = utf8.encode(text);
  if (_update) file..createSync(recursive: true)..writeAsBytesSync(bytes);
  expect(file.existsSync(), isTrue, reason: '$name has no golden: UPDATE_GOLDEN=1 writes it');
  expect(bytes, file.readAsBytesSync(), reason: name);
}

int _cents(String s) => s.isEmpty ? 0 : (double.parse(s.replaceAll(',', '.')) * 100).round();

void main() {
  test('the FEC books the charges as a sale, the credits as theirs, the refund as money out', () {
    final i = _mixed(20);
    expect(i.isCreditNote, isTrue, reason: 'the total is negative');
    expect(i.reversesSale, isFalse, reason: 'but the document charges something');
    final fec = _fec(i, _refund(i));
    final rows = [for (final l in const LineSplitter().convert(fec).skip(1)) l.split('\t')];
    // every amount is positive, every entry balances
    expect(rows.every((r) => !r[11].startsWith('-') && !r[12].startsWith('-')), isTrue);
    final byEntry = <String, int>{};
    for (final r in rows) {
      byEntry[r[2]] = (byEntry[r[2]] ?? 0) + _cents(r[11]) - _cents(r[12]);
    }
    expect(byEntry.values.every((v) => v == 0), isTrue, reason: '$byEntry');
    expect(byEntry.keys.toSet(), {'VE-F-1', 'BQ-F-1-C1', 'BQ-F-1-C2', 'BQ-F-1-R'});
    expect(fec.contains('Avoir'), isFalse);
    _golden('fec.txt', fec);
  });

  test('DATEV books the same document the same way, at 19 %', () {
    final i = _mixed(19);
    final package = _datev(i, _refund(i));
    expect(package.problems, isEmpty);
    final stapel = [
      for (final e in package.files.entries)
        if (e.key.startsWith('EXTF_Buchungsstapel_')) e.value,
    ].join();
    final bookings = [
      for (final l in const LineSplitter().convert(stapel.replaceAll('﻿', ''))
          .where((l) => !l.startsWith('"EXTF"') && !l.startsWith('Umsatz')))
        l.split(';'),
    ];
    // sale of 121.00 on revenue; two receipts (200.00, 40.00); one refund of 119.00 out
    expect([for (final b in bookings) '${b[0]} ${b[1].replaceAll('"', '')}'], unorderedEquals(['121,00 S', '200,00 S', '40,00 S', '119,00 S']));
    expect(stapel.contains('Gutschrift'), isFalse);
    expect(stapel.contains('Erstattung'), isTrue);
    for (final MapEntry(:key, :value) in package.files.entries) {
      _golden('datev/$key', value);
    }
  });

  test('a credit note whose positions are all reversals is still written as one', () {
    final credit = _mixed(20).copyWith(
      lines: const [InvoiceLine(kind: 'adjustment', label: 'Avoir', amountCents: -12000, vatPercent: 20)],
      totalCents: -12000,
      vatTotals: const [],
    );
    expect(credit.reversesSale, isTrue);
    expect(_fec(credit, const {}).contains('Avoir F-1'), isTrue);
    final package = _datev(credit, const {});
    expect(package.files.values.any((v) => v.contains('Gutschrift')), isTrue);
  });
}
