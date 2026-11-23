// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the GTIN check digit and the GS1 element string parser: AI 01 GTIN, 10 lot, 17 expiry, 21 serial,
// with the FNC1 separator, with parentheses and with a symbology identifier; a misread is not resolved.
import 'package:deskilo/core/scan/gs1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a GTIN is valid only with the right check digit, in the lengths of EAN-8, UPC-A, EAN-13 and GTIN-14', () {
    expect(gtinValid('4006381333931'), isTrue, reason: 'EAN-13');
    expect(gtinValid('4006381333932'), isFalse);
    expect(gtinValid('96385074'), isTrue, reason: 'EAN-8');
    expect(gtinValid('036000291452'), isTrue, reason: 'UPC-A');
    expect(gtinValid('04006381333931'), isTrue, reason: 'GTIN-14');
    expect(gtinValid('1234567'), isFalse);
    expect(gtinValid('40063813339A1'), isFalse);
  });

  test('a GS1 DataMatrix gives its GTIN, lot, expiry and serial; the variable fields end at the separator', () {
    final g = parseGs1('01040063813339311725123110LOT42\u001d21SER-9');
    expect(g?.gtin, '04006381333931');
    expect(g?.expiry, '2025-12-31');
    expect(g?.lot, 'LOT42');
    expect(g?.serial, 'SER-9');
  });

  test('the same text with parentheses or a symbology identifier reads the same', () {
    expect(parseGs1('(01)04006381333931(10)B7(17)260200')?.expiry, '2026-02-28', reason: 'day 00 is the last day of the month');
    expect(parseGs1(']d20104006381333931')?.gtin, '04006381333931');
  });

  test('a code with a wrong GTIN check digit, or with no GTIN, is not a GS1 code', () {
    expect(parseGs1('01040063813339321725123110LOT42'), isNull);
    expect(parseGs1('10LOT42'), isNull);
    expect(parseGs1('MAIN-SHELF-A'), isNull);
  });

  test('what a scan is for the goods sheets: a GTIN, a misread, a GS1 string, or anything else', () {
    expect(classifyGoodsCode('4006381333931').kind, GoodsCodeKind.gtin);
    expect(classifyGoodsCode('4006381333930').kind, GoodsCodeKind.misread);
    expect(classifyGoodsCode('0104006381333931').kind, GoodsCodeKind.gs1);
    expect(classifyGoodsCode('MUG-CARTON').kind, GoodsCodeKind.other);
    expect(classifyGoodsCode('MAG1-S4').kind, GoodsCodeKind.other);
  });

  test('an expiry day that is not a day of its month is refused, not rolled over', () {
    expect(parseGs1('(01)04006381333931(17)260231')?.expiry, isNull, reason: '31 February');
    expect(parseGs1('(01)04006381333931(17)261301')?.expiry, isNull, reason: 'month 13');
    expect(parseGs1('(01)04006381333931(17)260200')?.expiry, '2026-02-28', reason: 'day 00 is the last day: 28 days');
    expect(parseGs1('(01)04006381333931(17)240200')?.expiry, '2024-02-29', reason: 'and 29 in a leap year');
    expect(parseGs1('(01)04006381333931(17)260431')?.expiry, isNull, reason: '31 April');
    expect(parseGs1('(01)04006381333931(17)260231')?.gtin, '04006381333931', reason: 'the GTIN still reads');
  });

  test('a food label with dates before the lot keeps its lot and its expiry', () {
    // production date (11), packaging date (13) and best before (15) come before the lot
    final ok = parseGs1('0104006381333931112601011327010215261231' '10LOT7');
    expect(ok?.lot, 'LOT7');
    expect(ok?.expiry, '2026-12-31', reason: 'best before (15) is the expiry when 17 is absent');
    final both = parseGs1('0104006381333931152612311727010110LOT7');
    expect(both?.expiry, '2027-01-01', reason: '17 wins over 15');
    expect(both?.lot, 'LOT7');
  });

  test('a variable element runs to the separator or to the end, never cut at a guessed length', () {
    final g = parseGs1('01040063813339311727010110ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    expect(g?.lot, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', reason: '26 characters, all kept');
  });
}
