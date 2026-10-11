// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2385 — the one CSV cell writer. Every export quotes through it, so
// the formula-injection guard and the control-character cleaning hold
// for the audit trail, Sage, DATEV and the registers as they did for the
// accountant CSV alone.
import 'package:deskilo/core/text/csv.dart';
import 'package:deskilo/core/text/number_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('csvCell', () {
    test('RFC 4180 doubles a quote', () {
      expect(csvCell('Ana "AM"'), '"Ana ""AM"""');
    });

    test('Sage and DATEV turn a quote into an apostrophe', () {
      expect(csvCell('Ana "AM"', dialect: CsvDialect.sage), "\"Ana 'AM'\"");
      expect(csvCell('Ana "AM"', dialect: CsvDialect.datev), "\"Ana 'AM'\"");
    });

    test('control characters become one space in every dialect', () {
      for (final dialect in CsvDialect.values) {
        expect(csvCell('a\r\n\tb', dialect: dialect), '"a b"');
      }
    });

    test('DATEV also drops its separator and trims', () {
      expect(csvCell(' a;b ', dialect: CsvDialect.datev), '"a b"');
    });

    test('a formula start is defused with an apostrophe in every dialect', () {
      for (final dialect in CsvDialect.values) {
        for (final start in ['=', '+', '-', '@']) {
          expect(
            csvCell('${start}SUM(A1)', dialect: dialect),
            startsWith('"\''),
            reason: '$dialect $start',
          );
        }
      }
    });

    test('empty is nothing, or "" when the file quotes every text column', () {
      expect(csvCell(null), '');
      expect(csvCell(''), '');
      expect(csvCell('', quoteEmpty: true), '""');
    });

    test('maxLength cuts with an ellipsis', () {
      expect(csvCell('abcdef', maxLength: 4), '"abc…"');
    });
  });

  group('percentText', () {
    test('a whole rate has no decimals; a fractional one is as written', () {
      expect(percentText(20), '20');
      expect(percentText(5.5), '5.5');
      expect(percentText(5.5, decimalSeparator: ','), '5,5');
      expect(
        percentText(8.25, decimalSeparator: ',', fractionDigits: 1),
        '8,3',
      );
    });
  });
}
