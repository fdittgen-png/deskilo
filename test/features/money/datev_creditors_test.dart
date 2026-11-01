// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Kreditor of a supplier in the DATEV export (datev_creditors.dart): the
// supplier number gives the account inside DATEV's Kreditor range, the
// posting engine's purchases entries are booked against it row by row, and
// the Stammdaten name it. A number that gives no account stops the export
// and is named. The files are parsed field by field.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/datev_creditors.dart';
import 'package:deskilo/features/money/domain/datev_package.dart';
import 'package:deskilo/features/money/domain/datev_problem.dart';
import 'package:deskilo/features/money/domain/datev_stammdaten.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/datev_test_requests.dart';

PostingLine _line(
  BookRole role,
  String account, {
  int debit = 0,
  int credit = 0,
  String? qualifier,
}) => PostingLine(
  role: role,
  accountCode: account,
  qualifier: qualifier,
  debit: AccountingAmount('EUR', debit),
  credit: AccountingAmount('EUR', credit),
);

Posting _bill({
  String id = 'doc-1',
  String number = 'RE-77',
  DateTime? date,
}) => Posting(
  journal: PostingJournal.purchases,
  date: date ?? DateTime(2026, 3, 10),
  kind: PostingKind.supplierBill,
  documentId: id,
  documentNumber: number,
  lines: [
    _line(BookRole.expenses, '4980', debit: 10000),
    _line(BookRole.vatInput, '1576', debit: 1900, qualifier: 'standard'),
    _line(BookRole.suppliers, '1600', credit: 11900),
  ],
);

Posting _creditNote() => Posting(
  journal: PostingJournal.purchases,
  date: DateTime(2026, 3, 20),
  kind: PostingKind.supplierCreditNote,
  documentId: 'doc-2',
  documentNumber: 'GS-5',
  lines: [
    _line(BookRole.expenses, '4980', credit: 2000),
    _line(BookRole.vatInput, '1576', credit: 380, qualifier: 'standard'),
    _line(BookRole.suppliers, '1600', debit: 2380),
  ],
);

Posting _payment() => Posting(
  journal: PostingJournal.bank,
  date: DateTime(2026, 4, 2),
  kind: PostingKind.supplierPayment,
  documentId: 'doc-1',
  documentNumber: 'RE-77',
  lines: [
    _line(BookRole.suppliers, '1600', debit: 11900),
    _line(BookRole.bank, '1250', credit: 11900),
  ],
);

const _acme = PostingParty(kind: 'supplier', number: '7', name: 'Acme GmbH');

DatevPurchases _purchases(
  List<Posting> postings, {
  Map<String, PostingParty>? parties,
  int base = 70000,
  List<String> blocked = const [],
}) => DatevPurchases(
  creditorBase: base,
  postings: postings,
  parties: parties ?? {for (final p in postings) p.documentId: _acme},
  blocked: blocked,
);

DatevPackage _package(DatevPurchases? purchases) => buildDatevPackage(
  DatevPackageRequest(
    request: datevTestRequest(),
    bookProfiles: const [],
    closed: (from, to) => false,
    memberSequence: NumberSequence.defaultsFor('member'),
    debtorBase: 10000,
    purchases: purchases,
  ),
);

Map<String, List<List<String>>> _rows(DatevPackage p) => {
  for (final MapEntry(:key, :value) in p.files.entries)
    if (key.startsWith('EXTF_Buchungsstapel_'))
      key: datevTestParse(value).rows,
};

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('the Kreditor of a supplier number', () {
    String? creditor(String n, {int base = 70000, int length = 4}) =>
        datevCreditorOf(n, base: base, accountLength: length);

    test('the base plus the counter of the number', () {
      expect(creditor('7'), '70007');
      expect(creditor('0042'), '70042');
      expect(creditor('7', base: 80000), '80007');
      expect(creditor('12', base: 7000000, length: 6), '7000012');
    });

    test('Kreditor range follows the Sachkontenlänge', () {
      expect(DatevFormatRules.creditorRange(4), (70000, 99999));
      expect(DatevFormatRules.creditorRange(6), (7000000, 9999999));
      expect(DatevFormatRules.creditorRange(8), (700000000, 999999999));
    });

    test('a number that is not a counter, or past the range, gives none', () {
      expect(creditor(''), isNull);
      expect(creditor('ACME-7'), isNull);
      expect(creditor('7a'), isNull);
      expect(creditor('-7'), isNull);
      expect(creditor('30000'), isNull);
      expect(creditor('7', base: 1000), isNull);
      expect(creditor('1', base: 99999), isNull);
      expect(creditor('99999999999999999999'), isNull);
    });
  });

  group('the supplier postings as DATEV rows', () {
    late final package = _package(
      _purchases([_bill(), _creditNote(), _payment()]),
    );
    late final rows = _rows(package);

    test('nothing stops it', () => expect(package.problems, isEmpty));

    test('a bill: each line against the Kreditor, debit side S', () {
      final march = rows['EXTF_Buchungsstapel_202603_purchases.csv']!;
      final bill = march.where((r) => r[10] == 'RE-77').toList();
      expect(bill.map((r) => (r[0], r[1], r[6], r[7], r[8])), [
        ('100,00', 'S', '4980', '70007', ''),
        ('19,00', 'S', '1576', '70007', ''),
      ]);
      expect(bill.every((r) => r[9] == '1003'), isTrue);
      expect(bill.every((r) => r[13] == 'Eingangsrechnung RE-77'), isTrue);
    });

    test('the gross of the bill is what the Kreditor is credited', () {
      final march = rows['EXTF_Buchungsstapel_202603_purchases.csv']!;
      final credited = march
          .where((r) => r[10] == 'RE-77' && r[7] == '70007')
          .map((r) => int.parse(r[0].replaceAll(',', '')))
          .fold(0, (a, b) => a + b);
      expect(credited, 11900);
    });

    test('a credit note reverses it: the Kreditor on the debit side', () {
      final march = rows['EXTF_Buchungsstapel_202603_purchases.csv']!;
      final note = march.where((r) => r[10] == 'GS-5').toList();
      expect(note.map((r) => (r[0], r[1], r[6], r[7])), [
        ('20,00', 'S', '70007', '4980'),
        ('3,80', 'S', '70007', '1576'),
      ]);
      expect(note.every((r) => r[13] == 'Lieferantengutschrift GS-5'), isTrue);
    });

    test('a payment: the Kreditor debited, the bank credited, bank Stapel', () {
      expect(rows.containsKey('EXTF_Buchungsstapel_202604_purchases.csv'), isFalse);
      final april = rows['EXTF_Buchungsstapel_202604_bank.csv']!;
      final pay = april.where((r) => r[10] == 'RE-77').single;
      expect(
        (pay[0], pay[1], pay[6], pay[7], pay[9], pay[13]),
        ('119,00', 'S', '70007', '1250', '0204', 'Zahlung Lieferant RE-77'),
      );
    });

    test('the Stammdaten name the Kreditor once, beside nobody else', () {
      final s = datevTestParse(package.files[datevStammdatenFileName]!);
      final row = s.rows.singleWhere((r) => r.first == '70007');
      expect(row[5], 'Acme GmbH');
      expect(row[7], '7');
    });

    test('the rows count as the export rows', () {
      expect(package.rows, rows.values.expand((r) => r).length);
    });
  });

  group('what stops the export', () {
    test('a supplier number that gives no Kreditor is named', () {
      final p = _package(
        _purchases(
          [_bill()],
          parties: {
            'doc-1': const PostingParty(
              kind: 'supplier',
              number: 'ACME',
              name: 'Acme GmbH',
            ),
          },
        ),
      );
      expect(p.files, isEmpty);
      expect(
        p.problems.single,
        isA<DatevSupplierNumber>()
            .having((e) => e.supplier, 'supplier', 'Acme GmbH')
            .having((e) => e.number, 'number', 'ACME'),
      );
    });

    test('a bill with no supplier is named by its reference', () {
      final p = _package(_purchases([_bill()], parties: const {}));
      expect(
        p.problems.single,
        isA<DatevSupplierNumber>().having(
          (e) => e.supplier,
          'supplier',
          'RE-77',
        ),
      );
    });

    test('two suppliers on one Kreditor are named, nothing invented', () {
      final p = _package(
        _purchases(
          [_bill(), _bill(id: 'doc-9', number: 'RE-90')],
          parties: {
            'doc-1': const PostingParty(
              kind: 'supplier',
              number: '7',
              name: 'Acme GmbH',
            ),
            'doc-9': const PostingParty(
              kind: 'supplier',
              number: '007',
              name: 'Beta AG',
            ),
          },
        ),
      );
      expect(p.files, isEmpty);
      expect(
        p.problems.single,
        isA<DatevCreditorClash>()
            .having((e) => e.account, 'account', '70007')
            .having((e) => e.suppliers, 'suppliers', [
              'Acme GmbH',
              'Beta AG',
            ]),
      );
    });

    test('a number out of the Kreditor range is named', () {
      final p = _package(_purchases([_bill()], base: 99995));
      expect(
        p.problems.single,
        isA<DatevSupplierNumber>().having((e) => e.number, 'number', '7'),
      );
      expect(_package(_purchases([_bill()], base: 99990)).problems, isEmpty);
    });

    test('an account of another length than the header is named', () {
      final p = _package(
        _purchases([
          Posting(
            journal: PostingJournal.purchases,
            date: DateTime(2026, 3, 10),
            kind: PostingKind.supplierBill,
            documentId: 'doc-1',
            documentNumber: 'RE-77',
            lines: [
              _line(BookRole.expenses, '49800', debit: 11900),
              _line(BookRole.suppliers, '1600', credit: 11900),
            ],
          ),
        ]),
      );
      expect(p.problems.single, isA<DatevAccountLength>());
    });

    test('a posting in another currency than euro is named', () {
      final p = _package(
        _purchases([
          Posting(
            journal: PostingJournal.purchases,
            date: DateTime(2026, 3, 10),
            kind: PostingKind.supplierBill,
            documentId: 'doc-1',
            documentNumber: 'RE-77',
            lines: [
              PostingLine(
                role: BookRole.expenses,
                accountCode: '4980',
                debit: AccountingAmount('CHF', 1000),
                credit: AccountingAmount('CHF', 0),
              ),
              PostingLine(
                role: BookRole.suppliers,
                accountCode: '1600',
                debit: AccountingAmount('CHF', 0),
                credit: AccountingAmount('CHF', 1000),
              ),
            ],
          ),
        ]),
      );
      expect(
        p.problems.single,
        isA<DatevCurrency>().having((e) => e.given, 'given', 'CHF'),
      );
    });

    test('books the engine could not post are named, not skipped', () {
      final p = _package(
        _purchases(const [], blocked: ['suppliers', 'RE-1 (CHF)']),
      );
      expect(p.files, isEmpty);
      expect(
        p.problems.single,
        isA<DatevBooksBlocked>().having((e) => e.subjects, 'subjects', [
          'suppliers',
          'RE-1 (CHF)',
        ]),
      );
    });

    test('a Belegfeld 1 past its field is named, never cut', () {
      final p = _package(_purchases([_bill(number: 'R' * 40)]));
      expect(
        p.problems.single,
        isA<DatevReferenceTooLong>().having((e) => e.field, 'field', 'Belegfeld 1'),
      );
    });
  });

  group('a space without suppliers', () {
    test('is written byte for byte as before', () {
      final before = _package(null);
      final after = _package(_purchases(const []));
      expect(after.problems, isEmpty);
      expect(after.files, before.files);
      expect(after.rows, before.rows);
    });

    test('the postings of members are not the supplier side', () {
      final member = Posting(
        journal: PostingJournal.sales,
        date: DateTime(2026, 3, 10),
        kind: PostingKind.invoice,
        documentId: 'inv-1',
        documentNumber: 'INV-1',
        lines: [
          _line(BookRole.customers, '1400', debit: 100),
          _line(BookRole.revenue, '8400', credit: 100),
        ],
      );
      final after = _package(_purchases([member]));
      expect(after.files, _package(null).files);
    });
  });
}
