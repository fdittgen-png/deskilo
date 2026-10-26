// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is RFC 4180 and the column mapping
//
// #2380 — a CSV export is read through the person's column mapping: quoted
// fields with separators, doubled quotes and line breaks inside, a decimal
// comma and a thousands separator, credit and debit columns, a day pattern,
// and the account the person names. The separator is guessed from the
// header. A bad day refuses the file and names the 1-based line it starts on.
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/csv_statement.dart';
import 'package:flutter_test/flutter_test.dart';

const _limits = BankFileLimits(maxBytes: 1 << 20, maxLines: 100);

final _bytes = File('test/features/money/fixtures/bank/csv_statement.csv')
    .readAsBytesSync();

const _mapping = BankCsvMapping(
  account: 'CH93 0076 2011 6238 5295 7 (export)',
  delimiter: BankCsvDelimiters.semicolon,
  decimalComma: true,
  datePattern: BankCsvDatePattern.dayMonthYearDot,
  bookingDate: 0,
  valueDate: 1,
  counterpartyName: 2,
  counterpartyIban: 3,
  remittance: 4,
  reference: 5,
  credit: 6,
  debit: 7,
  transactionId: 8,
  fixedCurrency: 'chf',
);

BankStatement _read(List<int> bytes, [BankCsvMapping mapping = _mapping]) =>
    parseBankFile(
      bytes,
      format: BankFileFormat.csv,
      limits: _limits,
      csv: mapping,
    );

Matcher _refused(BankFileProblem p, {int? line}) => throwsA(
  isA<BankFileException>()
      .having((e) => e.problem, 'problem', p)
      .having((e) => line == null || e.line == line, 'line', isTrue),
);

void main() {
  final s = _read(_bytes);

  test('the header and the separator it uses', () {
    final first = String.fromCharCodes(_bytes).split('\r\n').first;
    expect(guessCsvDelimiter(first), BankCsvDelimiters.semicolon);
    expect(guessCsvDelimiter('a,b,c'), BankCsvDelimiters.comma);
    expect(guessCsvDelimiter('a\tb\tc'), BankCsvDelimiters.tab);
    expect(guessCsvDelimiter('"a;b",c'), BankCsvDelimiters.comma);
    expect(csvHeaderOf(_bytes, BankCsvDelimiters.semicolon), [
      'Buchungstag',
      'Valuta',
      'Auftraggeber',
      'IBAN',
      'Verwendungszweck',
      'Referenz',
      'Gutschrift',
      'Lastschrift',
      'Bank-ID',
    ]);
  });

  test('each row with its fields', () {
    expect(s.account, 'CH93 0076 2011 6238 5295 7 (export)');
    expect(s.currency, 'CHF');
    final [qrr, rf, out] = s.lines;
    expect(qrr.bookingDate, DateTime.utc(2026, 1, 15));
    expect(qrr.valueDate, DateTime.utc(2026, 1, 16));
    expect(qrr.amountCents, 12000);
    expect(qrr.counterpartyName, 'Demo Member One');
    expect(qrr.counterpartyIban, 'CH5604835012345678009');
    expect(qrr.remittance, 'Invoice 2026-0042; January');
    expect(qrr.reference, '210000000003139471430009017');
    expect(qrr.transactionId, 'TX-1');
    expect(rf.counterpartyName, 'Demo "Two" Member');
    expect(rf.amountCents, 123450, reason: 'a thousands separator');
    expect(rf.remittance, 'Payment RF18 5390 0754 7034');
    expect(rf.reference, 'RF18539007547034');
    expect(out.amountCents, -4500);
    expect(out.valueDate, out.bookingDate);
    expect(out.reference, '');
  });

  test('a signed amount column with a decimal point', () {
    const text =
        'date,amount,ccy\n2026-01-15,"1,234.50",EUR\n2026-01-16,-3,eur\n';
    final iso = _read(
      text.codeUnits,
      const BankCsvMapping(
        account: 'A-1',
        bookingDate: 0,
        amount: 1,
        currency: 2,
      ),
    );
    expect(iso.lines.map((l) => l.amountCents), [123450, -300]);
    expect(iso.currency, 'EUR');
  });

  test('a US day', () {
    final us = _read(
      'd,a\n01/31/2026,5\n'.codeUnits,
      const BankCsvMapping(
        account: 'A-1',
        bookingDate: 0,
        amount: 1,
        fixedCurrency: 'USD',
        datePattern: BankCsvDatePattern.monthDayYearSlash,
      ),
    );
    expect(us.lines.single.bookingDate, DateTime.utc(2026, 1, 31));
  });

  group('refusals, one change each', () {
    final text = String.fromCharCodes(_bytes);
    test('a bad day names the line it starts on', () {
      expect(
        () => _read(text.replaceFirst('22.01.2026', '32.01.2026').codeUnits),
        _refused(BankFileProblem.badDate, line: 5),
      );
    });
    test('an amount that is not one', () {
      expect(
        () => _read(text.replaceFirst(';45,00;', ';45,0x;').codeUnits),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('an unclosed quote', () {
      expect(
        () => _read(
          text.replaceFirst('"Demo Member One"', '"Demo Member One').codeUnits,
        ),
        _refused(BankFileProblem.malformed),
      );
    });
    test('no account named', () {
      expect(
        () => _read(
          _bytes,
          const BankCsvMapping(
            account: ' ',
            delimiter: BankCsvDelimiters.semicolon,
            decimalComma: true,
            datePattern: BankCsvDatePattern.dayMonthYearDot,
            bookingDate: 0,
            credit: 6,
            debit: 7,
            fixedCurrency: 'CHF',
          ),
        ),
        _refused(BankFileProblem.missingAccount),
      );
    });
    test('no currency', () {
      expect(
        () => _read(
          _bytes,
          const BankCsvMapping(
            account: 'A-1',
            delimiter: BankCsvDelimiters.semicolon,
            decimalComma: true,
            datePattern: BankCsvDatePattern.dayMonthYearDot,
            bookingDate: 0,
            credit: 6,
            debit: 7,
          ),
        ),
        _refused(BankFileProblem.badCurrency),
      );
    });
    test('only the header', () {
      expect(
        () => _read(text.split('\r\n').first.codeUnits),
        _refused(BankFileProblem.empty),
      );
    });
    test('no mapping', () {
      expect(
        () =>
            parseBankFile(_bytes, format: BankFileFormat.csv, limits: _limits),
        _refused(BankFileProblem.malformed),
      );
    });
  });
}
