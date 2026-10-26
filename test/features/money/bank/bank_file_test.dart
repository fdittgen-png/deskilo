// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the import's bounds and its formats
//
// #2380 — the one door a bank file comes in by: a file over the byte bound
// is refused before it is decoded, one over the line bound after it is
// read; the format is recognised from the bytes (a CSV never is: it needs
// its mapping); a byte-order mark is no content; an amount is exact in the
// currency's ISO 4217 minor units.
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/bank_values.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _fixture(String name) =>
    File('test/features/money/fixtures/bank/$name').readAsBytesSync();

Matcher _refused(BankFileProblem p) =>
    throwsA(isA<BankFileException>().having((e) => e.problem, 'problem', p));

void main() {
  const formats = {
    'camt053_statement.xml': BankFileFormat.camt053,
    'camt054_notification.xml': BankFileFormat.camt054,
    'six_rtgs_camt_054_sample.xml': BankFileFormat.camt054,
    'mt940_statement.sta': BankFileFormat.mt940,
    'coda_statement.cod': BankFileFormat.coda,
    'ofx_statement.ofx': BankFileFormat.ofx,
    'ofx2_statement.ofx': BankFileFormat.ofx,
  };

  test('each format is recognised from its bytes; a CSV is not', () {
    for (final MapEntry(key: name, value: format) in formats.entries) {
      expect(detectBankFormat(_fixture(name)), format, reason: name);
    }
    expect(detectBankFormat(_fixture('csv_statement.csv')), isNull);
    expect(detectBankFormat('hello'.codeUnits), isNull);
  });

  group('the bounds', () {
    final bytes = _fixture('camt053_statement.xml');

    test('one byte over the size is refused, at the size it is read', () {
      expect(
        () => parseBankFile(
          bytes,
          format: BankFileFormat.camt053,
          limits: BankFileLimits(maxBytes: bytes.length - 1, maxLines: 10),
        ),
        _refused(BankFileProblem.tooLarge),
      );
      expect(
        parseBankFile(
          bytes,
          format: BankFileFormat.camt053,
          limits: BankFileLimits(maxBytes: bytes.length, maxLines: 10),
        ).lines,
        hasLength(3),
      );
    });

    test('one line over the count is refused, at the count it is read', () {
      expect(
        () => parseBankFile(
          bytes,
          format: BankFileFormat.camt053,
          limits: const BankFileLimits(maxBytes: 1 << 20, maxLines: 2),
        ),
        _refused(BankFileProblem.tooManyLines),
      );
      expect(
        parseBankFile(
          bytes,
          format: BankFileFormat.camt053,
          limits: const BankFileLimits(maxBytes: 1 << 20, maxLines: 3),
        ).lines,
        hasLength(3),
      );
    });

    test('a byte-order mark is not content', () {
      expect(
        parseBankFile(
          [0xEF, 0xBB, 0xBF, ...bytes],
          format: BankFileFormat.camt053,
          limits: const BankFileLimits(maxBytes: 1 << 20, maxLines: 10),
        ).lines,
        hasLength(3),
      );
    });

    test('an entity declaration is refused, never expanded', () {
      final text = String.fromCharCodes(bytes)
          .replaceFirst('<Document', '<!ENTITY a "aaaa">\n<Document');
      expect(
        () => parseBankFile(
          text.codeUnits,
          format: BankFileFormat.camt053,
          limits: const BankFileLimits(maxBytes: 1 << 20, maxLines: 10),
        ),
        _refused(BankFileProblem.malformed),
      );
    });

    test('bytes that are not UTF-8 are refused for XML', () {
      expect(
        () => parseBankFile(
          [...bytes.take(100), 0xFF, 0xFE, ...bytes.skip(100)],
          format: BankFileFormat.camt053,
          limits: const BankFileLimits(maxBytes: 1 << 20, maxLines: 10),
        ),
        _refused(BankFileProblem.malformed),
      );
    });
  });

  group('amounts', () {
    test('minor units follow the ISO 4217 exponent', () {
      expect(CurrencyExponents.standard, 2);
      expect(CurrencyExponents.nonStandard, {
        'BHD': 3,
        'CLP': 0,
        'IQD': 3,
        'ISK': 0,
        'JOD': 3,
        'JPY': 0,
        'KRW': 0,
        'KWD': 3,
        'LYD': 3,
        'OMR': 3,
        'TND': 3,
        'VND': 0,
      });
      expect(bankAmount('1234', 'JPY'), 1234);
      expect(bankAmount('1.500', 'KWD'), 1500);
      expect(bankAmount('12.3', 'EUR'), 1230);
      expect(bankAmount('-0.07', 'EUR'), -7);
      expect(bankAmount("1'234.50", 'CHF', grouping: true), 123450);
      expect(
        bankAmount('1 234,50', 'EUR', decimalSeparator: ',', grouping: true),
        123450,
      );
      expect(bankAmount('10.000', 'EUR'), 1000, reason: 'zero decimals beyond');
    });

    test('a grouper is read only where the format allows one: a comma is '
        'never a thousands separator of a point-radix amount', () {
      for (final bad in ["1'234.50", '12,50', '1 234.50', '1.234,50']) {
        expect(
          () => bankAmount(bad, 'EUR'),
          _refused(BankFileProblem.badAmount),
          reason: bad,
        );
      }
      expect(
        () => bankAmount('1.234,50', 'EUR', decimalSeparator: ','),
        _refused(BankFileProblem.badAmount),
        reason: 'a point in a comma-radix amount without grouping',
      );
      expect(bankAmount('-12,50', 'EUR', decimalSeparator: ','), -1250);
    });

    test('a figure that is not exact is refused', () {
      for (final bad in ['1.5', '12.345', 'abc', '', '1e3', '99999999999999']) {
        expect(
          () => bankAmount(bad, bad == '1.5' ? 'JPY' : 'EUR'),
          _refused(BankFileProblem.badAmount),
          reason: bad,
        );
      }
    });

    test('a day that is not one is refused', () {
      expect(() => bankDay(2026, 2, 29), _refused(BankFileProblem.badDate));
      expect(bankDay(2028, 2, 29), DateTime.utc(2028, 2, 29));
    });
  });
}
