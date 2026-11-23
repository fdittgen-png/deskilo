// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (A0) -- a bounded, exact quantity: six fractional digits, as the
// stock ledger stores them (`numeric(18,6)`), kept as a scaled `BigInt` so a
// valid value never travels through a binary float or a web `int`.
//
// It has no unit, no currency, no price and no entitlement: a numeric value
// confers no right to consume stock or sell anything. The stock producer
// pairs it with an inventory unit and a conversion; the commercial-line
// producer with a billable unit and a price basis (#4162).
//
// The kernel reads locale-neutral CANONICAL decimal text only: a dot, no
// exponent, no grouping. A member's `0,5` is mapped to `0.5` by the
// application's input layer before it gets here.
import 'accounting_amount.dart';

/// Fractional digits of a stored quantity.
const int _scale = 6;

/// The largest magnitude, in millionths: `999999999999.999999`.
final BigInt _maxMicro = BigInt.parse('999999999999999999');

/// Why a text is not a quantity.
enum ExactQuantityProblem {
  /// Not plain decimal text: empty, signs, spaces, an exponent, a grouping
  /// or a decimal comma.
  malformed,

  /// More than six fractional digits (trailing zeros included): the entry is
  /// refused, never rounded.
  tooManyDecimals,

  /// A magnitude above `999999999999.999999`.
  outOfRange,

  /// A ratio (#4393: a quantity times a unit conversion) whose exact value
  /// has more than six decimals, such as one third: refused, never rounded.
  notRepresentable,

  /// A ratio whose denominator is zero.
  zeroDenominator,
}

/// A quantity that cannot be represented.
class ExactQuantityException implements Exception {
  const ExactQuantityException(this.problem, this.text);

  final ExactQuantityProblem problem;
  final String text;

  @override
  String toString() => 'ExactQuantityException(${problem.name}: $text)';
}

/// The outcome of reading a text: a value or a problem, never both.
typedef ExactQuantityResult = ({
  ExactQuantity? value,
  ExactQuantityProblem? problem,
});

/// An exact signed quantity of at most six decimals, `|v| <= 999999999999.999999`.
class ExactQuantity implements Comparable<ExactQuantity> {
  ExactQuantity._(this.micro);

  /// The signed value in millionths.
  final BigInt micro;

  static final ExactQuantity zero = ExactQuantity._(BigInt.zero);

  /// [text] as a quantity, or the reason it is none.
  static ExactQuantityResult tryParse(String text) {
    ExactQuantityResult refuse(ExactQuantityProblem p) =>
        (value: null, problem: p);
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text)) {
      return refuse(ExactQuantityProblem.malformed);
    }
    final decimal = ExactDecimal.parse(text);
    if (decimal.scale > _scale) {
      return refuse(ExactQuantityProblem.tooManyDecimals);
    }
    final micro =
        decimal.units * BigInt.from(10).pow(_scale - decimal.scale);
    if (micro.abs() > _maxMicro) return refuse(ExactQuantityProblem.outOfRange);
    return (value: ExactQuantity._(micro), problem: null);
  }

  /// [text] as a quantity; throws [ExactQuantityException] otherwise.
  factory ExactQuantity.parse(String text) {
    final r = tryParse(text);
    final value = r.value;
    if (value == null) throw ExactQuantityException(r.problem!, text);
    return value;
  }

  /// Millionths as a quantity (a stored `numeric(18,6)` read as an integer).
  factory ExactQuantity.fromMicro(BigInt micro) {
    if (micro.abs() > _maxMicro) {
      throw ExactQuantityException(
        ExactQuantityProblem.outOfRange,
        micro.toString(),
      );
    }
    return ExactQuantity._(micro);
  }

  /// #4393 -- this quantity times [numerator] / [denominator] (a unit
  /// conversion), exactly, or the reason it has no six-decimal value: a third
  /// of a unit is [ExactQuantityProblem.notRepresentable]. With [round] the
  /// value is rounded to six decimals, half away from zero, as the stock
  /// ledger's `round(q * num / den, 6)` records an entered quantity (0840).
  ExactQuantityResult scaled(int numerator, int denominator, {bool round = false}) {
    ExactQuantityResult refuse(ExactQuantityProblem p) =>
        (value: null, problem: p);
    if (denominator == 0) return refuse(ExactQuantityProblem.zeroDenominator);
    final product = micro * BigInt.from(numerator);
    final divisor = BigInt.from(denominator);
    final exact = product.remainder(divisor) == BigInt.zero;
    if (!exact && !round) return refuse(ExactQuantityProblem.notRepresentable);
    final result = exact ? product ~/ divisor : _halfAwayFromZero(product, divisor);
    if (result.abs() > _maxMicro) return refuse(ExactQuantityProblem.outOfRange);
    return (value: ExactQuantity._(result), problem: null);
  }

  static BigInt _halfAwayFromZero(BigInt n, BigInt d) {
    final negative = n.isNegative != d.isNegative;
    final a = n.abs();
    final b = d.abs();
    final q = (a * BigInt.two + b) ~/ (b * BigInt.two);
    return negative ? -q : q;
  }

  bool get isZero => micro == BigInt.zero;
  bool get isNegative => micro.isNegative;

  /// The same value as an [ExactDecimal].
  ExactDecimal get decimal => ExactDecimal.parse(text);

  ExactQuantity operator -() => ExactQuantity._(-micro);

  /// The sum; throws when it leaves the representable range.
  ExactQuantity operator +(ExactQuantity other) =>
      ExactQuantity.fromMicro(micro + other.micro);

  ExactQuantity operator -(ExactQuantity other) =>
      ExactQuantity.fromMicro(micro - other.micro);

  bool operator <(ExactQuantity other) => micro < other.micro;
  bool operator <=(ExactQuantity other) => micro <= other.micro;
  bool operator >(ExactQuantity other) => micro > other.micro;
  bool operator >=(ExactQuantity other) => micro >= other.micro;

  @override
  int compareTo(ExactQuantity other) => micro.compareTo(other.micro);

  @override
  bool operator ==(Object other) => other is ExactQuantity && other.micro == micro;

  @override
  int get hashCode => micro.hashCode;

  /// The canonical text: a dot, no exponent or grouping, no redundant
  /// leading zeros, no trailing fractional zeros, no decimal point on an
  /// integer, one spelling of zero. Signatures and digests compare this.
  String get text {
    if (micro == BigInt.zero) return '0';
    final digits = micro.abs().toString().padLeft(_scale + 1, '0');
    final whole = digits.substring(0, digits.length - _scale);
    final fraction = digits
        .substring(digits.length - _scale)
        .replaceFirst(RegExp(r'0+$'), '');
    final sign = micro.isNegative ? '-' : '';
    return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
  }

  @override
  String toString() => text;
}
