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
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _bom = '\u{FEFF}';

/// [i] at German rates (19 % and 7 %), with the buyer as frozen at issue.
Invoice _german(Invoice i, {String number = '10042', String site = ''}) =>
    i.copyWith(
      lines: [
        for (final l in i.lines)
          l.copyWith(
            vatPercent: switch (l.vatPercent) {
              20 => 19,
              5.5 => 7,
              final p => p,
            },
          ),
      ],
      buyerParty: InvoiceParty(
        name: 'Ana Kowalczyk',
        memberNumber: number,
        street: 'Leopoldstraße 1',
        postalCode: '80802',
        city: 'München',
        country: 'DE',
      ),
      sellerParty: seededCompany.copyWith(site: site),
    );

List<Invoice> get _year => [
  for (final i in SeededExportYear.acceptanceInvoices)
    _german(i, site: i.number == 'INV-2' ? 'Schwabing' : ''),
];

DatevRequest _request({
  List<Invoice>? invoices,
  DatevAccounts accounts = const DatevAccounts(),
  String consultant = '1234567',
  String client = '54321',
}) => DatevRequest(
  invoices: invoices ?? _year,
  matches: SeededExportYear.acceptanceMatches,
  accounts: accounts,
  from: DateTime(2026),
  to: DateTime(2026, 12, 31),
  generatedAt: DateTime(2027, 1, 5, 9),
  consultantNumber: consultant,
  clientNumber: client,
  batchName: 'Bürogemeinschaft München Schwabing Nord',
  ledger: [
    for (final e in SeededExportYear.ledger)
      if (e.createdAt.year == 2026) e,
  ],
);

DatevPackage _package({
  DatevRequest? request,
  int rowsPerBatch = 99999,
  Map<String, String> memberNumbers = const {},
}) => buildDatevPackage(
  DatevPackageRequest(
    request: request ?? _request(),
    bookProfiles: const [],
    closed: (from, to) => !to.isAfter(DateTime(2026, 4, 30)),
    defaultCostCentre: 'Cowork',
    memberNumbers: memberNumbers,
    voucherLinks: true,
    rowsPerBatch: rowsPerBatch,
  ),
);

/// A parsed Buchungsstapel: its header fields and its rows' fields.
typedef _Batch = ({List<String> header, List<List<String>> rows});

_Batch _parse(String file) {
  expect(file.startsWith(_bom), isTrue, reason: 'the BOM comes first');
  final lines = file.substring(1).split('\r\n');
  expect(lines.last, isEmpty, reason: 'CRLF after the last row');
  return (
    header: _fields(lines[0]),
    rows: [
      for (final l in lines.skip(2).where((l) => l.isNotEmpty))
        _fields(l),
    ],
  );
}

/// The fields of one line; a quoted field may hold doubled quotes.
List<String> _fields(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ';' && !quoted) {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  out.add(b.toString());
  return out;
}

Map<String, _Batch> _batches(DatevPackage p) => {
  for (final MapEntry(:key, :value) in p.files.entries)
    if (key.startsWith('EXTF_Buchungsstapel_')) key: _parse(value),
};

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('the Debitor of a member number', () {
    test('a counter becomes the first Debitor plus it', () {
      expect(datevDebtorOf('M-0007', 4), '10007');
      expect(datevDebtorOf('42', 4), '10042');
      expect(datevDebtorOf('M-0007', 5), '100007');
    });

    test('a number that already is a Debitor is kept', () {
      expect(datevDebtorOf('23456', 4), '23456');
      expect(datevDebtorOf('69999', 4), '69999');
    });

    test('no digits, or past the range, gives none', () {
      expect(datevDebtorOf('', 4), isNull);
      expect(datevDebtorOf('M-', 4), isNull);
      expect(datevDebtorOf('M-60000', 4), isNull);
      expect(DatevFormatRules.debtorRange(4), (10000, 69999));
      expect(DatevFormatRules.debtorRange(6), (1000000, 6999999));
    });
  });

  group('the seeded year as the accountant imports it', () {
    late final package = _package();
    late final batches = _batches(package);

    test('nothing stops it', () => expect(package.problems, isEmpty));

    test('a sales and a bank Buchungsstapel per month, each its own month',
        () {
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
        for (final r in b.rows.where((r) => r[10].startsWith(RegExp('INV|CN')))) {
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
          expect(r, hasLength(116));
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
      final s = _parse(package.files[datevStammdatenFileName]!);
      expect(s.header.take(5), ['EXTF', '700', '16', 'Debitoren/Kreditoren', '5']);
      expect({for (final r in s.rows) r[0]}, used);
      final ana = s.rows.single;
      expect([ana[5], ana[6], ana[7], ana[15], ana[17], ana[18], ana[19]], [
        'Ana Kowalczyk', '0', '10042', 'Leopoldstraße 1', '80802', 'München',
        'DE',
      ]);
    });

    test('the vouchers are the documents the rows link', () {
      expect(
        package.vouchers.map((i) => i.number).toSet(),
        {'INV-1', 'INV-2', 'INV-3', 'CN-1', 'INV-4', 'INV-5'},
      );
    });
  });

  test('a month over the row limit is cut into numbered Stapel', () {
    final package = _package(rowsPerBatch: 1);
    final march = package.files.keys
        .where((k) => k.contains('202603_bank'))
        .toList()
      ..sort();
    expect(march, [
      'EXTF_Buchungsstapel_202603_bank.csv',
      'EXTF_Buchungsstapel_202603_bank_2.csv',
    ]);
    for (final k in march) {
      expect(_parse(package.files[k]!).rows, hasLength(1));
    }
  });

  group('what stops the export, named', () {
    test('numbers DATEV refuses', () {
      final p = _package(request: _request(consultant: '12', client: 'ab'));
      expect(p.files, isEmpty);
      expect(p.problems, [
        isA<DatevConsultantNumber>(),
        isA<DatevClientNumber>(),
      ]);
    });

    test('a member with no number, the member named', () {
      final p = _package(
        request: _request(invoices: [
          for (final i in _year) i.copyWith(buyerParty: const InvoiceParty()),
        ]),
      );
      final problem = p.problems.single as DatevMemberNumber;
      expect((problem.member, problem.number), ('Ana', ''));
    });

    test('the number the member holds today stands in for none frozen', () {
      final p = _package(
        request: _request(invoices: [
          for (final i in _year) i.copyWith(buyerParty: const InvoiceParty()),
        ]),
        memberNumbers: const {'m1': 'M-0003'},
      );
      expect(p.problems, isEmpty);
      expect(_parse(p.files[datevStammdatenFileName]!).rows.single.first, '10003');
    });

    test('two members on one Debitor', () {
      final other = _german(SeededExportYear.inv2, number: 'M-42')
          .copyWith(id: 'x', number: 'INV-9', memberId: 'm2');
      final p = _package(request: _request(invoices: [..._year, other]));
      final clash = p.problems.single as DatevDebtorClash;
      expect(clash.account, '10042');
    });

    test('an account not as long as the header says', () {
      final p = _package(
        request: _request(accounts: const DatevAccounts(bank: '12000')),
      );
      expect(
        p.problems.whereType<DatevAccountLength>().map((x) => x.account),
        ['12000'],
      );
    });
  });

  group('the BU-Schlüssel of a non-automatic account (#2365 hand-off)', () {
    late TaxReferenceSet installed;
    setUp(() => installed = ActiveTaxReference.current);
    tearDown(() => ActiveTaxReference.install(installed));

    void withKeys() => ActiveTaxReference.install(TaxReferenceSet([
      ...installed.rows,
      for (final (group, key) in [('standard', '3'), ('reduced', '2')])
        TaxReferenceRow(
          country: 'DE',
          key: 'datev/tax:$group',
          validFrom: '1900-01-01',
          value: AccountMapValue(format: 'datev', role: 'tax:$group', taxCode: key),
          source: 'test',
          confirmed: true,
        ),
    ]));

    List<(String, String, String)> revenueRows(DatevPackage p) => [
      for (final b in _batches(p).values)
        for (final r in b.rows)
          if (r[13].startsWith('Rechnung INV-2') || r[13].startsWith('Rechnung INV-1'))
            (r[0], r[7], r[8]),
    ];

    test('19 % on the owner\'s revenue account carries key 3; 7 % stays on '
        'its automatic account without one', () {
      withKeys();
      final p = _package(
        request: _request(accounts: const DatevAccounts(revenue: '8000')),
      );
      expect(p.problems, isEmpty);
      expect(revenueRows(p), [
        ('120,00', '8000', '3'),
        ('105,50', '8300', ''),
        ('200,00', '8000', '3'),
      ]);
    });

    test('an automatic account carries no key', () {
      withKeys();
      expect(revenueRows(_package()).map((r) => r.$3).toSet(), {''});
    });

    test('without the reference key the export stops, the rate named', () {
      final p = _package(
        request: _request(accounts: const DatevAccounts(revenue: '8000')),
      );
      final missing = p.problems.single as DatevTaxKeyMissing;
      expect((missing.percent, missing.account), (19.0, '8000'));
      expect(p.files, isEmpty);
    });

    test('a rate on the automatic account of another rate stops it', () {
      withKeys();
      final p = _package(
        request: _request(accounts: const DatevAccounts(revenue: '8300')),
      );
      final clash = p.problems.whereType<DatevAutomaticClash>().single;
      expect((clash.percent, clash.account), (19.0, '8300'));
    });
  });
}
