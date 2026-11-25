// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till's numeric keypad and calculator, without floating point: the keypad builds a quantity as the reader
// types it (the locale's decimal separator, at most six decimals, as the server takes a quantity); the calculator works
// on exact decimals in millionths, and its result goes onto a line as a quantity, never as a price it may not set.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity, exactQuantityScale;

import '../../../core/format/decimal_input.dart';

/// What the keypad has typed: digits and at most one decimal separator, shown as typed.
class TillKeypadEntry {
  const TillKeypadEntry([this.text = '']);

  final String text;

  /// The most digits after the separator: the server's quantity has six.
  static const maxDecimals = 6;

  /// The most characters a typed quantity has.
  static const maxLength = 16;

  bool get isEmpty => text.isEmpty;

  /// [key] typed: a digit, [separator] (the locale's decimal mark) once, or nothing when it would break the shape.
  TillKeypadEntry type(String key, {required String separator}) {
    if (text.length >= maxLength) return this;
    final sep = text.indexOf(separator);
    if (key == separator) return sep >= 0 ? this : TillKeypadEntry(text.isEmpty ? '0$separator' : '$text$separator');
    if (key.length != 1 || key.codeUnitAt(0) < 0x30 || key.codeUnitAt(0) > 0x39) return this;
    if (sep >= 0 && text.length - sep - 1 >= maxDecimals) return this;
    if (text == '0') return TillKeypadEntry(key);
    return TillKeypadEntry('$text$key');
  }

  TillKeypadEntry back() => text.isEmpty ? this : TillKeypadEntry(text.substring(0, text.length - 1));
}

/// The calculator's operations.
enum TillCalcOp { add, subtract, multiply, divide, percent }

/// A millionth is the kernel's quantity unit (`numeric(18,6)`).
final BigInt _scale = BigInt.from(10).pow(exactQuantityScale);

/// A decimal text (a comma or a point, no grouping) in millionths; null when it is not a number of at most six decimals.
int? tillMillionths(String text) {
  final read = exactQuantityFromInput(text.trim(), grouping: false, allowNegative: true).value;
  if (read == null || read.micro.abs() >= _ceiling) return null;
  return read.micro.toInt();
}

/// Millionths as a plain decimal text with a point, trailing zeros dropped (`1.5`, `12`, `-0.25`).
String tillDecimalText(int millionths) => ExactQuantity.fromMicro(BigInt.from(millionths)).text;

/// Twelve whole digits: the most the calculator shows.
final BigInt _ceiling = BigInt.from(10).pow(12) * _scale;

/// [a] [op] [b], exactly in millionths, rounded half up to six decimals for a division; null when [b] is zero for a
/// division or the result leaves the twelve whole digits.
int? tillCalculate(int a, TillCalcOp op, int b) {
  const big = BigInt.from;
  final scale = _scale;
  BigInt divRound(BigInt n, BigInt d) {
    final q = n.abs() * big(2) + d.abs();
    final r = q ~/ (d.abs() * big(2));
    return (n.isNegative != d.isNegative) ? -r : r;
  }

  final BigInt r;
  switch (op) {
    case TillCalcOp.add:
      r = big(a) + big(b);
    case TillCalcOp.subtract:
      r = big(a) - big(b);
    case TillCalcOp.multiply:
      r = divRound(big(a) * big(b), scale);
    case TillCalcOp.divide:
      if (b == 0) return null;
      r = divRound(big(a) * scale, big(b));
    case TillCalcOp.percent:
      r = divRound(big(a) * big(b), scale * big(100));
  }
  if (r.abs() >= _ceiling) return null;
  return r.toInt();
}
