// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till's keypad and calculator: the French "1,5" is typed with the locale's mark and reads as the exact
// quantity 1.5; the keypad refuses a second mark, a seventh decimal and anything but digits; the calculator is exact in
// millionths, rounds a division half up at six decimals, refuses a division by zero and a result past twelve digits.
import 'package:deskilo/features/money/domain/till_keypad.dart';
import 'package:deskilo/features/money/domain/till_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

TillKeypadEntry _type(String keys, {String sep = ','}) {
  var e = const TillKeypadEntry();
  for (final k in keys.split('')) {
    e = e.type(k, separator: sep);
  }
  return e;
}

void main() {
  test('1,5 typed in French is the exact quantity 1.5', () {
    final e = _type('1,5');
    expect(e.text, '1,5');
    expect(tillQuantityOf(e.text), '1.5');
  });

  test('a second mark, a seventh decimal and a letter are not typed', () {
    expect(_type('1,,5').text, '1,5');
    expect(_type('0,1234567').text, '0,123456');
    expect(_type('1a2').text, '12');
    expect(_type(',5').text, '0,5', reason: 'a mark first reads as 0,');
    expect(_type('05').text, '5', reason: 'no leading zero');
    expect(_type('2.5', sep: '.').text, '2.5');
    expect(_type('12').back().text, '1');
  });

  test('the calculator is exact', () {
    int m(String t) => tillMillionths(t)!;
    expect(tillDecimalText(tillCalculate(m('0,1'), TillCalcOp.add, m('0,2'))!), '0.3');
    expect(tillDecimalText(tillCalculate(m('1,5'), TillCalcOp.multiply, m('3'))!), '4.5');
    expect(tillDecimalText(tillCalculate(m('10'), TillCalcOp.divide, m('3'))!), '3.333333');
    expect(tillDecimalText(tillCalculate(m('2'), TillCalcOp.divide, m('3'))!), '0.666667', reason: 'half up at six');
    expect(tillDecimalText(tillCalculate(m('80'), TillCalcOp.percent, m('15'))!), '12');
    expect(tillDecimalText(tillCalculate(m('5'), TillCalcOp.subtract, m('7,25'))!), '-2.25');
  });

  test('a division by zero and a result past twelve digits are refused', () {
    expect(tillCalculate(tillMillionths('5')!, TillCalcOp.divide, 0), isNull);
    expect(tillCalculate(tillMillionths('999999999999')!, TillCalcOp.multiply, tillMillionths('10')!), isNull);
    expect(tillMillionths('1,2345678'), isNull);
    expect(tillMillionths('abc'), isNull);
  });
}
