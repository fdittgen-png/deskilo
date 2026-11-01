// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the FEC's BQ entry of an invoice matched to a bank statement line
// carries the statement's value date (PieceDate) and the line's reference
// (PieceRef). The entry's own date (EcritureDate, the day it was booked) and
// ValidDate stay what they were: the dates are three facts, and none is
// derived from another. A posting with no statement line is byte-identical
// to what it was. Expectations by hand.
import 'package:deskilo/features/money/domain/fec_postings.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _receipt(
  String number,
  String date, {
  String? valueDate,
  String? reference,
  int cents = 12000,
}) => {
  'journal': 'bank',
  'kind': 'receipt',
  'date': date,
  'document_id': 'id-$number',
  'document_number': number,
  'currency': 'EUR',
  'value_date': ?valueDate,
  'bank_reference': ?reference,
  'lines': [
    {
      'role': 'bank',
      'qualifier': null,
      'account_code': '512000',
      'debit_cents': cents,
      'credit_cents': 0,
    },
    {
      'role': 'customers',
      'qualifier': null,
      'account_code': '411000',
      'debit_cents': 0,
      'credit_cents': cents,
    },
  ],
};

List<List<String>> _rows(List<Map<String, Object?>> postings) {
  final set = PostingSet.fromJson({'postings': postings, 'blockers': const []});
  final file = buildFecFromPostings(
    set.postings,
    accountNames: const {},
    parties: {
      for (final p in set.postings)
        p.documentId: const PostingParty(
          kind: 'member',
          number: 'M-0007',
          name: 'Ana Lopez',
        ),
    },
  ).file;
  return [for (final l in file.split('\r\n').skip(1)) l.split('\t')];
}

void main() {
  // Column indexes: EcritureNum 2, EcritureDate 3, PieceRef 8, PieceDate 9,
  // EcritureLib 10, ValidDate 15.
  test('a matched receipt carries the line value date and reference', () {
    final rows = _rows([
      _receipt(
        'INV-1',
        '2026-03-10',
        valueDate: '2026-03-07',
        reference: 'RF18539007547034',
      ),
    ]);
    expect(rows, hasLength(2));
    for (final r in rows) {
      expect(r[2], 'BQ-INV-1');
      expect(r[3], '20260310', reason: 'the entry date is the booking day');
      expect(r[9], '20260307', reason: 'the piece date is the value date');
      expect(r[8], 'RF18539007547034');
      expect(r[10], 'Encaissement INV-1', reason: 'the label keeps the invoice');
      expect(r[15], '20260310', reason: 'ValidDate is not the value date');
    }
  });

  test('a line without a reference keeps the document as the piece', () {
    final r = _rows([
      _receipt('INV-2', '2026-03-10', valueDate: '2026-03-08'),
    ]).first;
    expect((r[8], r[9]), ('INV-2', '20260308'));
  });

  test('a posting with no statement line is written as it always was', () {
    final r = _rows([_receipt('INV-3', '2026-03-10')]).first;
    expect((r[3], r[8], r[9], r[15]), ('20260310', 'INV-3', '20260310', '20260310'));
  });

  test('two lines of the same amount and booking day keep their own dates', () {
    final rows = _rows([
      _receipt('INV-4', '2026-03-10', valueDate: '2026-03-05', reference: 'A1'),
      _receipt('INV-5', '2026-03-10', valueDate: '2026-03-06', reference: 'B2'),
    ]);
    final byEntry = {for (final r in rows) r[2]: (r[8], r[9])};
    expect(byEntry, {
      'BQ-INV-4': ('A1', '20260305'),
      'BQ-INV-5': ('B2', '20260306'),
    });
  });
}
