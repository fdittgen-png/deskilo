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
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';
import 'accounting_connection.dart';
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


/// The rows of [postings], one list per posting, in their order: entries
/// numbered per journal (`VE-0001`, `BQ-0001`, ...), amounts in major units
/// with a point, the tax code the rate group of a tax line.
List<List<List<String>>> _postingRows(List<Posting> postings) {
  final next = <PostingJournal, int>{};
  final out = <List<List<String>>>[];
  for (final p in postings) {
    final n = next[p.journal] = (next[p.journal] ?? 0) + 1;
    final number = '${p.journal.code}-${n.toString().padLeft(4, '0')}';
    out.add([
      for (final l in p.lines)
        [
          isoDay(p.date),
          number,
          l.accountCode,
          _amount(l.debit),
          _amount(l.credit),
          '${p.documentNumber} ${p.kind.wire}',
          '',
          '',
          if (l.role == BookRole.vatOutput || l.role == BookRole.vatInput)
            l.qualifier ?? ''
          else
            '',
        ],
    ]);
  }
  return out;
}

String _line(List<String> row) => row.map(csvCell).join(',');

/// The journal of [postings], in their order.
String buildGenericJournalCsv(List<Posting> postings) {
  final rows = [
    _header,
    for (final posting in _postingRows(postings)) ...posting,
  ];
  return '${rows.map(_line).join('\r\n')}\r\n';
}

/// The documents the journal of [postings] carries, one per document event
/// (its kind, document and day), each with the sha256 of its own rows as
/// the file writes them. A closed period written again gives the same
/// digests, which is what lets a re-delivery change nothing.
List<FileDocument> genericJournalDocuments(List<Posting> postings) {
  final rows = _postingRows(postings);
  final byEvent = <String, ({Posting first, StringBuffer text})>{};
  for (var i = 0; i < postings.length; i++) {
    final p = postings[i];
    final event = byEvent.putIfAbsent(
      '${p.kind.wire}|${p.documentId}|${isoDay(p.date)}',
      () => (first: p, text: StringBuffer()),
    );
    for (final row in rows[i]) {
      event.text.write('${_line(row)}\r\n');
    }
  }
  return [
    for (final e in byEvent.values)
      FileDocument(
        kind: e.first.kind.wire,
        id: e.first.documentId,
        number: e.first.documentNumber,
        date: e.first.date,
        sha256: sha256.convert(utf8.encode(e.text.toString())).toString(),
      ),
  ];
}
