// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till's numeric keypad and calculator, without floating point: the keypad builds a quantity as the reader
// types it (the locale's decimal separator, at most six decimals, as the server takes a quantity); the calculator works
// on exact decimals in millionths, and its result goes onto a line as a quantity, never as a price it may not set.

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

const int _scale = 1000000;

/// A decimal text (a comma or a point) in millionths; null when it is not a number of at most six decimals.
int? tillMillionths(String text) {
  final t = text.trim().replaceAll(',', '.');
  final m = RegExp(r'^(-?)(\d{1,12})(?:\.(\d{1,6}))?$').firstMatch(t);
  if (m == null) return null;
  final whole = int.parse(m.group(2)!) * _scale + int.parse((m.group(3) ?? '').padRight(6, '0'));
  return m.group(1) == '-' ? -whole : whole;
}

/// Millionths as a plain decimal text with a point, trailing zeros dropped (`1.5`, `12`, `-0.25`).
String tillDecimalText(int millionths) {
  final sign = millionths < 0 ? '-' : '';
  final a = millionths.abs();
  final fraction = (a % _scale).toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
  return '$sign${a ~/ _scale}${fraction.isEmpty ? '' : '.$fraction'}';
}

/// [a] [op] [b], exactly in millionths, rounded half up to six decimals for a division; null when [b] is zero for a
/// division or the result leaves the twelve whole digits.
int? tillCalculate(int a, TillCalcOp op, int b) {
  const big = BigInt.from;
  final scale = big(_scale);
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
  if (r.abs() >= BigInt.from(1000000000000) * scale) return null;
  return r.toInt();
}
