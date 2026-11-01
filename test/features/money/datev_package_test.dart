// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The DATEV export as the accountant imports it (datev_package.dart): every
// customer row on the member's 5-digit Debitor in DATEV's range, KOST1 on
// every row, an automatic account or a BU-Schlüssel per rate, Belegfeld 1
// the document number, Festschreibung 1 in a closed month, a sales and a
// bank Buchungsstapel per month of at most the row limit, the Stammdaten
// naming every Debitor used, and the format's own rules (BOM, DDMM, field
// lengths, positive amounts). The files are parsed here, field by field, not
// compared with the builder's own strings; and an export DATEV would refuse
// or misbook is not written at all.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/datev_debtors.dart';
import 'package:deskilo/features/money/domain/datev_package.dart';
import 'package:deskilo/features/money/domain/datev_problem.dart';
import 'package:deskilo/features/money/domain/datev_stammdaten.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/datev_test_requests.dart';
import 'support/seeded_export_year.dart';

DatevPackage _package({
  DatevRequest? request,
  int rowsPerBatch = 99999,
  Map<String, String> memberNumbers = const {},
}) => buildDatevPackage(
  DatevPackageRequest(
    request: request ?? datevTestRequest(),
    bookProfiles: const [],
    closed: (from, to) => !to.isAfter(DateTime(2026, 4, 30)),
    memberSequence: NumberSequence.defaultsFor('member'),
    debtorBase: 10000,
    memberNumbers: memberNumbers,
    rowsPerBatch: rowsPerBatch,
  ),
);

Map<String, DatevTestBatch> _batches(DatevPackage p) => {
  for (final MapEntry(:key, :value) in p.files.entries)
    if (key.startsWith('EXTF_Buchungsstapel_')) key: datevTestParse(value),
};

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('the Debitor of a member number', () {
    String? debtor(
      String number, {
      NumberSequence? sequence,
      int base = 10000,
      int length = 4,
    }) => datevDebtorOf(
      number,
      sequence: sequence ?? NumberSequence.defaultsFor('member'),
      base: base,
      accountLength: length,
    );

    test('the counter of the member series above the first Debitor', () {
      expect(debtor('M-0007'), '10007');
      expect(debtor('M-0007', base: 20000), '20007');
      expect(debtor('M-0007', base: 100000, length: 5), '100007');
    });

    test('a series with a date part gives its counter, not its date', () {
      const monthly = NumberSequence(
        journal: 'member',
        prefix: 'M-',
        datePart: NumberDatePart.yearMonth,
      );
      expect(monthly.format(7, DateTime(2026, 3)), 'M-2026-03-0007');
      expect(debtor('M-2026-03-0007', sequence: monthly), '10007');
      const yearly = NumberSequence(journal: 'member', prefix: 'M-');
      expect(debtor('M-2026-0007', sequence: yearly), '10007');
    });

    test('a number not of the series, or past the range, gives none', () {
      expect(debtor(''), isNull);
      expect(debtor('X-0007'), isNull);
      expect(debtor('M-60000'), isNull);
      expect(debtor('M-0007', base: 1000), isNull);
      expect(DatevFormatRules.debtorRange(4), (10000, 69999));
      expect(DatevFormatRules.debtorRange(6), (1000000, 6999999));
    });
  });

  group('the seeded year as the accountant imports it', () {
    late final package = _package();
    late final batches = _batches(package);

    test('nothing stops it', () => expect(package.problems, isEmpty));

    test('a sales and a bank Buchungsstapel per month, each its own month', () {
      final byMonth = <String, Set<String>>{};
      for (final MapEntry(:key, value: b) in batches.entries) {
        final m = RegExp(r'_(\d{6})_(sales|bank)\.csv$').firstMatch(key)!;
        (byMonth[m.group(1)!] ??= {}).add(m.group(2)!);
        // Datum vom / bis: the first and last day of that month.
        expect(b.header[14], '${m.group(1)}01', reason: key);
        expect(b.header[15].substring(0, 6), m.group(1), reason: key);
        // Every row's Belegdatum lies in it.
        for (final r in b.rows) {
          expect(r[9].substring(2), m.group(1)!.substring(4), reason: key);
        }
        final bank = m.group(2) == 'bank';
        for (final r in b.rows) {
          expect(r[6] == '1200' || r[7] == '1200', bank, reason: key);
        }
      }
      // March to June move money and sell in the same month: two Stapel.
      for (final month in ['202603', '202604', '202605', '202606']) {
        expect(byMonth[month], {'sales', 'bank'}, reason: month);
      }
    });

    test('every row books the member on a 5-digit Debitor in range', () {
      for (final MapEntry(:key, value: b) in batches.entries) {
        for (final r in b.rows) {
          final personal = [r[6], r[7]].where((a) => a.length == 5).toList();
          final isRepartition = r[6] == '4900' && r[7] == '1200';
          if (isRepartition) continue;
          expect(personal, hasLength(1), reason: '$key ${r.take(14)}');
          final n = int.parse(personal.single);
          expect(n, inInclusiveRange(10000, 69999));
          expect(personal.single, '10042');
        }
      }
    });

    test('KOST1 on every row: the document site, else the space', () {
      for (final b in batches.values) {
        for (final r in b.rows) {
          expect(r[36], r[10] == 'INV-2' ? 'Schwabing' : 'Cowork');
          expect(r[36].length, lessThanOrEqualTo(36));
        }
      }
    });

    test('Belegfeld 1 is the number; Beleginfo and Beleglink name it', () {
      for (final b in batches.values) {
        for (final r in b.rows.where(
          (r) => r[10].startsWith(RegExp('INV|CN')),
        )) {
          expect(r[19], 'BEDI "id-${r[10]}"');
          expect([r[20], r[21]], ['Rechnungsnummer', r[10]]);
          expect(r[22], 'Belegdatum');
        }
      }
    });

    test('each rate on its automatic account, without a key', () {
      final revenue = [
        for (final b in batches.values)
          for (final r in b.rows)
            if (r[13].startsWith('Rechnung') || r[13].startsWith('Gutschrift'))
              (r[6] == '10042' ? r[7] : r[6], r[8]),
      ];
      expect(revenue.map((e) => e.$1).toSet(), {'8400', '8300'});
      expect(revenue.map((e) => e.$2).toSet(), {''});
    });

    test('Festschreibung 1 in a closed month, 0 in an open one', () {
      for (final MapEntry(:key, value: b) in batches.entries) {
        final closed = int.parse(key.substring(24, 26)) <= 4;
        expect(b.header[20], closed ? '1' : '0', reason: key);
        for (final r in b.rows) {
          expect(r[113], closed ? '1' : '', reason: key);
        }
      }
    });

    test('the format rules: lengths, DDMM, positive comma amounts, 116 '
        'fields, Bezeichnung at most 30', () {
      for (final MapEntry(:key, value: b) in batches.entries) {
        expect(b.header.take(5), ['EXTF', '700', '21', 'Buchungsstapel', '13']);
        expect(b.header[16].runes.length, lessThanOrEqualTo(30), reason: key);
        for (final r in b.rows) {
          expect(r, hasLength(DatevFormatRules.rowFields));
          expect(r[0], matches(RegExp(r'^\d+,\d\d$')));
          expect(r[1], 'S');
          expect(r[9], matches(RegExp(r'^\d{4}$')));
          expect(r[10].runes.length, lessThanOrEqualTo(36));
          expect(r[13].runes.length, lessThanOrEqualTo(60));
        }
      }
    });

    test('the Stammdaten name every Debitor the Stapel use', () {
      final used = {
        for (final b in batches.values)
          for (final r in b.rows) ...[r[6], r[7]].where((a) => a.length == 5),
      };
      final s = datevTestParse(package.files[datevStammdatenFileName]!);
      expect(s.header.take(5), [
        'EXTF',
        '700',
        '16',
        'Debitoren/Kreditoren',
        '5',
      ]);
      expect({for (final r in s.rows) r[0]}, used);
      final ana = s.rows.single;
      expect(
        [ana[5], ana[6], ana[7], ana[15], ana[17], ana[18], ana[19]],
        [
          'Ana Kowalczyk',
          '0',
          'M-0042',
          'Leopoldstraße 1',
          '80802',
          'München',
          'DE',
        ],
      );
    });

    test('the vouchers are the documents the rows link', () {
      expect(package.vouchers.map((i) => i.number).toSet(), {
        'INV-1',
        'INV-2',
        'INV-3',
        'CN-1',
        'INV-4',
        'INV-5',
      });
    });
  });

  test('a month over the row limit is cut into numbered Stapel', () {
    final package = _package(rowsPerBatch: 1);
    final march =
        package.files.keys.where((k) => k.contains('202603_bank')).toList()
          ..sort();
    expect(march, [
      'EXTF_Buchungsstapel_202603_bank.csv',
      'EXTF_Buchungsstapel_202603_bank_2.csv',
    ]);
    for (final k in march) {
      expect(datevTestParse(package.files[k]!).rows, hasLength(1));
    }
  });

  group('what stops the export, named', () {
    test('numbers DATEV refuses', () {
      final p = _package(
        request: datevTestRequest(consultant: '12', client: 'ab'),
      );
      expect(p.files, isEmpty);
      expect(p.problems, [
        isA<DatevConsultantNumber>(),
        isA<DatevClientNumber>(),
      ]);
    });

    test('a member with no number, the member named', () {
      final p = _package(
        request: datevTestRequest(
          invoices: [
            for (final i in datevYear) i.copyWith(buyerParty: const InvoiceParty()),
          ],
        ),
      );
      final problem = p.problems.single as DatevMemberNumber;
      expect((problem.member, problem.number), ('Ana', ''));
    });

    test('the number the member holds today stands in for none frozen', () {
      final p = _package(
        request: datevTestRequest(
          invoices: [
            for (final i in datevYear) i.copyWith(buyerParty: const InvoiceParty()),
          ],
        ),
        memberNumbers: const {'m1': 'M-0003'},
      );
      expect(p.problems, isEmpty);
      expect(
        datevTestParse(p.files[datevStammdatenFileName]!).rows.single.first,
        '10003',
      );
    });

    test('two members on one Debitor', () {
      final other = datevGerman(
        SeededExportYear.inv2,
        number: 'M-42',
      ).copyWith(id: 'x', number: 'INV-9', memberId: 'm2');
      final p = _package(request: datevTestRequest(invoices: [...datevYear, other]));
      final clash = p.problems.single as DatevDebtorClash;
      expect(clash.account, '10042');
    });

    test('a workspace not in euros, the currency named', () {
      final p = _package(request: datevTestRequest(currency: 'CHF'));
      expect(p.files, isEmpty);
      expect((p.problems.single as DatevCurrency).given, 'CHF');
    });

    test('a Sachkontenlänge DATEV does not know', () {
      final p = _package(request: datevTestRequest(accountLength: 9));
      expect((p.problems.single as DatevSachkontenlaenge).length, 9);
    });

    test('a 37-character invoice number is refused, never cut', () {
      final long = 'R' * 37;
      final p = _package(
        request: datevTestRequest(
          invoices: [
            for (final i in datevYear)
              if (i.number == 'INV-2') i.copyWith(number: long) else i,
          ],
        ),
      );
      final refused = p.problems.single as DatevReferenceTooLong;
      expect((refused.field, refused.value), ('Belegfeld 1', long));
      expect(p.files, isEmpty);
    });

    test('an account not as long as the header says', () {
      final p = _package(
        request: datevTestRequest(accounts: const DatevAccounts(bank: '12000')),
      );
      expect(p.problems.whereType<DatevAccountLength>().map((x) => x.account), [
        '12000',
      ]);
    });
  });

  group('the BU-Schlüssel of a non-automatic account (#2365 hand-off, '
      '#2375 keys)', () {
    late TaxReferenceSet installed;
    setUp(() => installed = ActiveTaxReference.current);
    tearDown(() => ActiveTaxReference.install(installed));

    // The bundled reference holds the keys (`datev/tax:<group>`); this
    // removes them, as an installation that never received them.
    void withoutKeys() => ActiveTaxReference.install(
      TaxReferenceSet([
        for (final row in installed.rows)
          if (!row.key.startsWith('datev/tax:')) row,
      ]),
    );

    List<(String, String, String)> revenueRows(DatevPackage p) => [
      for (final b in _batches(p).values)
        for (final r in b.rows)
          if (r[13].startsWith('Rechnung INV-2') ||
              r[13].startsWith('Rechnung INV-1'))
            (r[0], r[7], r[8]),
    ];

    test('19 % on the owner\'s revenue account carries the bundled key 3; '
        '7 % stays on its automatic account without one', () {
      final p = _package(
        request: datevTestRequest(accounts: const DatevAccounts(revenue: '8000')),
      );
      expect(p.problems, isEmpty);
      expect(revenueRows(p), [
        ('120,00', '8000', '3'),
        ('105,50', '8300', ''),
        ('200,00', '8000', '3'),
      ]);
    });

    test('7 % on a non-automatic account carries the bundled key 2', () {
      // A reference with no automatic account for the reduced rate books it
      // to the owner's revenue account, which then needs the rate's key.
      ActiveTaxReference.install(
        TaxReferenceSet([
          for (final row in installed.rows)
            if (!row.key.startsWith('datev/revenue:reduced')) row,
        ]),
      );
      final p = _package(
        request: datevTestRequest(accounts: const DatevAccounts(revenue: '8000')),
      );
      expect(p.problems, isEmpty);
      expect(revenueRows(p).map((r) => (r.$2, r.$3)).toSet(), {
        ('8000', '3'),
        ('8000', '2'),
      });
    });

    test('an automatic account carries no key', () {
      expect(revenueRows(_package()).map((r) => r.$3).toSet(), {''});
    });

    test('without the reference key the export stops, the rate named', () {
      withoutKeys();
      final p = _package(
        request: datevTestRequest(accounts: const DatevAccounts(revenue: '8000')),
      );
      final missing = p.problems.single as DatevTaxKeyMissing;
      expect((missing.percent, missing.account), (19.0, '8000'));
      expect(p.files, isEmpty);
    });

    test('a rate on the automatic account of another rate stops it', () {
      final p = _package(
        request: datevTestRequest(accounts: const DatevAccounts(revenue: '8300')),
      );
      final clash = p.problems.whereType<DatevAutomaticClash>().single;
      expect((clash.percent, clash.account), (19.0, '8300'));
    });
  });

  test('a document is dated on the workspace calendar, wherever the export '
      'is made', () {
    WorkspaceTime.install('Pacific/Auckland');
    // 31 March 12:00 UTC is 1 April 01:00 in Auckland.
    final boundary = datevGerman(
      SeededExportYear.inv2,
    ).copyWith(issuedAt: DateTime.utc(2026, 3, 31, 12));
    final p = _package(request: datevTestRequest(invoices: [boundary]));
    expect(p.problems, isEmpty);
    final april = datevTestParse(p.files['EXTF_Buchungsstapel_202604_sales.csv']!);
    final sale = april.rows.single;
    expect(sale[9], '0104');
    expect(sale[23], '01.04.2026');
    expect(p.files.keys.where((k) => k.contains('202603_sales')), isEmpty);
  });
}
