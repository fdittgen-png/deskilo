// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — the generic journal file: one row per posting line of the
// posting engine (`compute_postings`), the fallback every accounting system
// without a national format can import (Date, JournalNo, Account, Debit,
// Credit, Description, Name, Dimension, TaxCode). It serialises the
// postings and decides nothing: an entry the engine blocked never reaches
// it.
//
// Pure Dart.
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';

const _header = [
  'Date',
  'JournalNo',
  'Account',
  'Debit',
  'Credit',
  'Description',
  'Name',
  'Dimension',
  'TaxCode',
];

/// A side of a line: empty when it carries nothing.
String _amount(AccountingAmount a) => a.minor == 0 ? '' : a.toDecimalString();


/// The journal of [postings], in their order: entries numbered per journal
/// (`VE-0001`, `BQ-0001`, ...), amounts in major units with a point, the
/// tax code the rate group of a tax line.
String buildGenericJournalCsv(List<Posting> postings) {
  final rows = <List<String>>[_header];
  final next = <PostingJournal, int>{};
  for (final p in postings) {
    final n = next[p.journal] = (next[p.journal] ?? 0) + 1;
    final number = '${p.journal.code}-${n.toString().padLeft(4, '0')}';
    for (final l in p.lines) {
      final taxCode =
          l.role == BookRole.vatOutput || l.role == BookRole.vatInput
          ? l.qualifier ?? ''
          : '';
      rows.add([
        isoDay(p.date),
        number,
        l.accountCode,
        _amount(l.debit),
        _amount(l.credit),
        '${p.documentNumber} ${p.kind.wire}',
        '',
        '',
        taxCode,
      ]);
    }
  }
  return '${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';
}
