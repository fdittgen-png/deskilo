// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the helpers the country add-ons and the application share: the date
// spellings of the filing files, the month-or-quarter reading of a period, the
// registration numbers a return checks and prints, and the one CSV cell writer
// (control characters, formula injection, the dialects). The application pins
// the date spellings to its own and keeps the old vectors of the others.
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';
import 'package:test/test.dart';

void main() {
  test('the shared date spellings', () {
    final d = DateTime.utc(2026, 3, 4, 9, 5);
    expect(ymd(d), '20260304');
    expect(ymd(d, separator: '-'), '2026-03-04');
    expect(hhmm(d), '09:05');
    expect(hhmm(d, separator: ''), '0905');
    expect(ymd(DateTime.utc(7, 1, 2)), '00070102');
  });

  test('the shared helpers: periods, registration numbers, csv cells', () {
    expect(monthOrQuarter(DateTime(2026, 3), DateTime(2026, 3, 31)), (
      month: 3,
      quarter: null,
    ));
    expect(monthOrQuarter(DateTime(2026, 4), DateTime(2026, 6, 30)), (
      month: null,
      quarter: 2,
    ));
    expect(monthOrQuarter(DateTime(2026), DateTime(2026, 12, 31)), isNull);
    expect(monthOrQuarter(DateTime(2026, 2), DateTime(2026, 4, 30)), isNull);
    expect(monthOrQuarter(DateTime(2026, 3, 2), DateTime(2026, 3, 31)), isNull);
    expect(isValidCanadianBn('123456789 RT0001'), isTrue);
    expect(isValidCanadianBn('123456789'), isFalse);
    expect(isValidQstNumber('1234567890 TQ0001'), isTrue);
    expect(formatCanadianRegistration('123456789rt0001'), '123456789 RT0001');
    expect(formatCanadianRegistration('nope'), 'nope');
    expect(csvCell('=SUM(A1)'), '"\'=SUM(A1)"');
    expect(csvCell('a "b"'), r'''"a ""b"""''');
  });

  test('csv dialects and limits', () {
    expect(csvCell(null), '');
    expect(csvCell('', quoteEmpty: true), '""');
    expect(csvCell('a\tb\nc'), '"a b c"');
    expect(csvCell('x;y', dialect: CsvDialect.datev), '"x y"');
    expect(csvCell('a "b"', dialect: CsvDialect.sage), "\"a 'b'\"");
    expect(csvCell('abcdef', maxLength: 4), '"abc…"');
    expect(csvCell('-5'), "\"'-5\"");
  });
}
