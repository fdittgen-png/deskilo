// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- the exact decimal of a commercial line: its limits, its problems
// and its canonical text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// At most six fractional digits, the precision of the physical ledger
/// (`numeric(18,6)`), and twelve integer digits.
const int _commercialDecimalScale = 6;
const int _commercialQuantityIntegerDigits = 12;

/// Why a quantity or a price is not accepted.
enum CommercialDecimalProblem {
  /// Not plain `[-]digits[.digits]`.
  malformed,

  /// A quantity that is zero, or negative outside a correction.
  notPositive,

  /// More than the decimal scale fractional digits: refused, never
  /// rounded.
  excessPrecision,

  /// More than the integer-digit limit integer digits.
  outOfRange,
}

/// An exact decimal of a commercial line, with its canonical text.
class CommercialDecimal {
  const CommercialDecimal._(this.value, this.text);

  final ExactDecimal value;

  /// Plain decimal text without trailing fractional zeros (`1.5`, `2`).
  final String text;

  @override
  bool operator ==(Object other) =>
      other is CommercialDecimal && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => text;
}

/// The outcome of reading one decimal: its value or its problem, never both.
typedef CommercialDecimalResult = ({
  CommercialDecimal? value,
  CommercialDecimalProblem? problem,
});

/// Reads [text] as an exact decimal of a commercial line. A quantity is
/// positive ([positive]); a correction names its source and may be negative
/// ([allowNegative]); a price may be zero but never negative.
CommercialDecimalResult parseCommercialDecimal(
  String text, {
  bool positive = true,
  bool allowNegative = false,
}) {
  final ExactDecimal d;
  try {
    d = ExactDecimal.parse(text);
  } on AccountingException {
    return (value: null, problem: CommercialDecimalProblem.malformed);
  }
  if (d.scale > _commercialDecimalScale) {
    // Trailing zeros beyond the sixth place are not information, but the
    // wire carries canonical text: refuse rather than normalise silently.
    return (value: null, problem: CommercialDecimalProblem.excessPrecision);
  }
  final zero = d.units == BigInt.zero;
  if (positive && (zero || (d.units.isNegative && !allowNegative))) {
    return (value: null, problem: CommercialDecimalProblem.notPositive);
  }
  if (!positive && d.units.isNegative && !allowNegative) {
    return (value: null, problem: CommercialDecimalProblem.notPositive);
  }
  final integer = d.units.abs() ~/ d.denominator;
  if (integer.toString().length > _commercialQuantityIntegerDigits) {
    return (value: null, problem: CommercialDecimalProblem.outOfRange);
  }
  return (value: CommercialDecimal._(d, _canonical(d)), problem: null);
}

String _canonical(ExactDecimal d) {
  final s = d.toString();
  if (!s.contains('.')) return s;
  final trimmed = s.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

