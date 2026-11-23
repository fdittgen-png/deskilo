// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- the exact decimal of a commercial line: its limits, its problems
// and its canonical text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// At most six fractional digits, the precision of the physical ledger
/// (`numeric(18,6)`), and twelve integer digits: the kernel's ExactQuantity bounds (#4406).

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
///
/// #4406 -- the grammar, the six-decimal scale, the twelve integer digits and
/// the canonical text are the kernel's `ExactQuantity` (one implementation);
/// this adds the commercial rules (sign) and keeps its own problem names.
CommercialDecimalResult parseCommercialDecimal(
  String text, {
  bool positive = true,
  bool allowNegative = false,
}) {
  final trimmed = text.trim();
  final read = ExactQuantity.tryParse(trimmed);
  final q = read.value;
  if (q == null) {
    return (
      value: null,
      problem: switch (read.problem!) {
        ExactQuantityProblem.tooManyDecimals => CommercialDecimalProblem.excessPrecision,
        ExactQuantityProblem.outOfRange => CommercialDecimalProblem.outOfRange,
        _ => CommercialDecimalProblem.malformed,
      },
    );
  }
  if (positive && (q.isZero || (q.isNegative && !allowNegative))) {
    return (value: null, problem: CommercialDecimalProblem.notPositive);
  }
  if (!positive && q.isNegative && !allowNegative) {
    return (value: null, problem: CommercialDecimalProblem.notPositive);
  }
  return (value: CommercialDecimal._(ExactDecimal.parse(trimmed), q.text), problem: null);
}
