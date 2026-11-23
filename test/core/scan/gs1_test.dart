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
}
