// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0642) — money out reconciled with a bank statement line carries
// the line's value date and reference, as a receipt does: the FEC writes
// them as PieceDate and PieceRef (EcritureDate and ValidDate stay the
// entry's), the DATEV Kreditor's payment row as Beleginfo pairs
// (Valutadatum, Bankreferenz) while its Belegdatum stays the entry's date.
// A payment without them is written as it always was. Expectations by hand.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/datev_creditors.dart';
import 'package:deskilo/features/money/domain/datev_package.dart';
import 'package:deskilo/features/money/domain/fec_postings.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/datev_test_requests.dart';

/// A payment out of 119.00 on [date] as the engine answers it (0642).
Map<String, Object?> _payment(
  String kind,
  String number,
  String date, {
  String? valueDate,
  String? reference,
}) => {
  'journal': 'bank',
  'kind': kind,
  'date': date,
  'document_id': 'doc-$number',
  'document_number': number,
  'currency': 'EUR',
  'value_date': ?valueDate,
  'bank_reference': ?reference,
  'lines': [
    {
      'role': kind == 'reimbursement' ? 'customers' : 'suppliers',
      'qualifier': null,
      'account_code': kind == 'reimbursement' ? '1400' : '1600',
      'debit_cents': 11900,
      'credit_cents': 0,
    },
    {
      'role': 'bank',
      'qualifier': null,
      'account_code': '1250',
      'debit_cents': 0,
      'credit_cents': 11900,
    },
  ],
};

List<Posting> _postings(List<Map<String, Object?>> raw) =>
    PostingSet.fromJson({'postings': raw, 'blockers': const []}).postings;

const _acme = PostingParty(kind: 'supplier', number: '7', name: 'Acme GmbH');

List<List<String>> _fec(List<Map<String, Object?>> raw) {
  final postings = _postings(raw);
  final file = buildFecFromPostings(
    postings,
    accountNames: const {},
    parties: {for (final p in postings) p.documentId: _acme},
  ).file;
  return [for (final l in file.split('\r\n').skip(1)) l.split('\t')];
}

/// The RE-77 rows of the April bank Stapel of a DATEV package of [raw]
/// (the test request's own invoices book there too).
List<List<String>> _datevApril(List<Map<String, Object?>> raw) {
  final postings = _postings(raw);
  final package = buildDatevPackage(
    DatevPackageRequest(
      request: datevTestRequest(),
      bookProfiles: const [],
      closed: (from, to) => false,
      memberSequence: NumberSequence.defaultsFor('member'),
      debtorBase: 10000,
      purchases: DatevPurchases(
        creditorBase: 70000,
        postings: postings,
        parties: {for (final p in postings) p.documentId: _acme},
      ),
    ),
  );
  expect(package.problems, isEmpty);
  return datevTestParse(package.files['EXTF_Buchungsstapel_202604_bank.csv']!)
      .rows
      .where((r) => r[10] == 'RE-77')
      .toList();
}

/// The Beleginfo pairs (fields 21 to 36) of [row], as (Art, Inhalt).
List<(String, String)> _info(List<String> row) => [
  for (var k = 0; k < 8; k++)
    if (row[20 + 2 * k].isNotEmpty) (row[20 + 2 * k], row[21 + 2 * k]),
];

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('the FEC', () {
    // Column indexes: EcritureDate 3, PieceRef 8, PieceDate 9, ValidDate 15.
    test('a supplier payment carries the line value date and reference', () {
      final rows = _fec([
        _payment(
          'supplier_payment',
          'RE-77',
          '2026-04-02',
          valueDate: '2026-04-01',
          reference: 'RF71OUT0001',
        ),
      ]);
      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r[3], '20260402', reason: 'the entry date is the payment day');
        expect(r[8], 'RF71OUT0001');
        expect(r[9], '20260401', reason: 'the piece date is the value date');
        expect(r[15], '20260402', reason: 'ValidDate is not the value date');
      }
    });

    test('a reimbursement too, and without a reference the document stays '
        'the piece', () {
      final r = _fec([
        _payment(
          'reimbursement',
          'NDF-3',
          '2026-04-02',
          valueDate: '2026-04-03',
        ),
      ]).first;
      expect((r[3], r[8], r[9]), ('20260402', 'NDF-3', '20260403'));
    });

    test('a payment no line explains is written as it always was', () {
      final r = _fec([_payment('supplier_payment', 'RE-78', '2026-04-02')])
          .first;
      expect(
        (r[3], r[8], r[9], r[15]),
        ('20260402', 'RE-78', '20260402', '20260402'),
      );
    });
  });

  group('the DATEV Kreditor payment row', () {
    test('carries Valutadatum and Bankreferenz; Belegdatum stays the '
        'payment day', () {
      final pay = _datevApril([
        _payment(
          'supplier_payment',
          'RE-77',
          '2026-04-02',
          valueDate: '2026-04-01',
          reference: 'RF71OUT0001',
        ),
      ]).single;
      expect(_info(pay), [
        ('Valutadatum', '01.04.2026'),
        ('Bankreferenz', 'RF71OUT0001'),
      ]);
      expect(pay[9], '0204', reason: 'Belegdatum decides the Stapel');
      expect(
        (pay[0], pay[1], pay[6], pay[7], pay[13]),
        ('119,00', 'S', '70007', '1250', 'Zahlung Lieferant RE-77'),
      );
    });

    test('a line without a reference gives the value date alone', () {
      final pay = _datevApril([
        _payment(
          'supplier_payment',
          'RE-77',
          '2026-04-02',
          valueDate: '2026-04-03',
        ),
      ]).single;
      expect(_info(pay), [('Valutadatum', '03.04.2026')]);
    });

    test('a payment without the facts is the same row as before', () {
      final plain = _datevApril([
        _payment('supplier_payment', 'RE-77', '2026-04-02'),
      ]).single;
      expect(_info(plain), isEmpty);
      final explained = _datevApril([
        _payment(
          'supplier_payment',
          'RE-77',
          '2026-04-02',
          valueDate: '2026-04-01',
          reference: 'RF71OUT0001',
        ),
      ]).single;
      expect(
        [
          for (var i = 0; i < explained.length; i++)
            if (i < 20 || i > 23) explained[i],
        ],
        [
          for (var i = 0; i < plain.length; i++)
            if (i < 20 || i > 23) plain[i],
        ],
        reason: 'only the Beleginfo pairs differ',
      );
    });
  });
}
