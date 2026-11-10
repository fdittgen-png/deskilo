// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 -- the Sage 50 Canada general-journal text file: an Ontario invoice at
// HST 13 %, a Québec invoice at GST 5 % + QST 9.975 % (two tax lines), a
// credit note, an expense with input tax, and the refusals. Byte-pinned in
// goldens/sage50_ca_journal.txt (UPDATE_GOLDEN=1 rewrites it).
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/sage50_ca_journal.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

AccountingAmount _c(int minor) => AccountingAmount('CAD', minor);

PostingLine _line(BookRole role, String account, int minor, {bool debit = true, String? group}) =>
    PostingLine(
      role: role,
      accountCode: account,
      debit: _c(debit ? minor : 0),
      credit: _c(debit ? 0 : minor),
      qualifier: group,
    );

String _group(double percent) =>
    ActiveTaxReference.current.groupOfRate('CA', percent, 'S');

Posting _sale(String number, DateTime day, int net, int tax, double percent,
    {bool credit = false}) {
  final g = _group(percent);
  return Posting(
    journal: PostingJournal.sales,
    date: day,
    kind: credit ? PostingKind.creditNote : PostingKind.invoice,
    documentId: number,
    documentNumber: number,
    lines: [
      _line(BookRole.customers, '1200', net + tax, debit: !credit),
      _line(BookRole.revenue, '4020', net, debit: credit, group: g),
      _line(BookRole.vatOutput, '2310', tax, debit: credit, group: g),
    ],
  );
}

final _postings = [
  _sale('INV-ON-1', DateTime(2026, 3, 4), 10000, 1300, 13),
  _sale('INV-QC-1', DateTime(2026, 3, 5), 10000, 1498, 14.975),
  _sale('CN-QC-1', DateTime(2026, 3, 9), 2000, 299, 14.975, credit: true),
  Posting(
    journal: PostingJournal.purchases,
    date: DateTime(2026, 3, 12),
    kind: PostingKind.expense,
    documentId: 'B-1',
    documentNumber: 'B-1',
    lines: [
      _line(BookRole.expenses, '5300', 5000, group: _group(13)),
      _line(BookRole.vatInput, '2315', 650, group: _group(13)),
      _line(BookRole.suppliers, '2100', 5650, debit: false),
    ],
  ),
];

Sage50CaJournal _build() => buildSage50CaJournal(
  _postings,
  comment: (p) => '${p.documentNumber} ${p.kind.wire}',
  split: sage50CaTaxSplit(ActiveTaxReference.current),
);

void main() {
  test('the journal of the year is byte-pinned', () {
    final content = (_build() as Sage50CaFile).content;
    final golden = File('test/features/money/goldens/sage50_ca_journal.txt');
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      golden.writeAsStringSync(content);
    }
    expect(content, golden.readAsStringSync());
  });

  test('Ontario states one HST line, Québec states the GST and the QST', () {
    final lines = (_build() as Sage50CaFile).content.split('\r\n');
    expect(lines, contains(startsWith('03-04-26,"INV-ON-1"')));
    expect(lines, contains('TAXD,2310,"HST","HST",100.00,13.00,0.00'));
    expect(lines.where((l) => l.contains('"HST"') && l.contains('100.00,14.98')), isEmpty);
    final gst = lines.where((l) => l.startsWith('TAXD,2310,"GST"'));
    final qst = lines.where((l) => l.startsWith('TAXD,2310,"QST"'));
    expect(gst, isNotEmpty);
    expect(qst, isNotEmpty);
    // INV-QC-1: GST 5 % of 100.00 and QST 9.975 % of 100.00, two lines.
    expect(lines, contains('TAXH,2,0'));
    expect(lines, contains('TAXD,2310,"GST","GST",100.00,5.00,0.00'));
    expect(lines, contains('TAXD,2310,"QST","QST",100.00,9.98,0.00'));
  });

  test('every transaction sums to zero, debits positive and credits negative', () {
    final lines = (_build() as Sage50CaFile).content.split('\r\n');
    var sum = 0.0;
    var inTransaction = false;
    for (final l in lines) {
      if (l.isEmpty || l.startsWith('TAXH') || l.startsWith('TAXD')) continue;
      if (l.contains('"')) {
        if (inTransaction) expect(sum.abs(), lessThan(0.005), reason: l);
        sum = 0;
        inTransaction = true;
      } else {
        sum += double.parse(l.split(',')[1]);
      }
    }
    expect(sum.abs(), lessThan(0.005));
  });

  test('a credit note reverses its tax lines, input tax is a purchases header', () {
    final lines = (_build() as Sage50CaFile).content.split('\r\n');
    expect(lines.where((l) => l.startsWith('TAXD,2310') && l.contains(',-')), isNotEmpty);
    expect(lines, contains('TAXH,1,1'));
  });

  test('a source over 20 characters or an unusable account stops the file', () {
    final long = Posting(
      journal: PostingJournal.sales,
      date: DateTime(2026),
      kind: PostingKind.invoice,
      documentId: 'x',
      documentNumber: 'INV-2026-0000000000001',
      lines: [
        _line(BookRole.customers, '12,00', 100),
        _line(BookRole.revenue, '4020', 100, debit: false),
      ],
    );
    final result = buildSage50CaJournal(
      [long],
      comment: (_) => '',
      split: (_, _, _) => const [],
    );
    result as Sage50CaRefused;
    expect(result.sourceTooLong, ['INV-2026-0000000000001']);
    expect(result.unusableAccounts, ['12,00']);
  });
}
