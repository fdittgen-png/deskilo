// SPDX-License-Identifier: AGPL-3.0-or-later
//
// An amount a person types, read for ONE currency. Validity is decided by
// the shared decimal reader (`parseDecimalInput`) and by the conversion to
// that currency's minor units, nothing else:
//   * what the decimal reader refuses (a letter, an exponent such as
//     `12e3`, a doubled separator) is not a number;
//   * a negative amount where the field allows none is refused, never
//     turned positive;
//   * more decimals than the currency carries (`1.5` yen, `1.2345` dinar)
//     is refused, never rounded.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'decimal_input.dart';

/// Why a typed amount was refused.
enum AmountInputProblem { notANumber, negative, tooManyDecimals }

/// What a typed amount reads as: [minor] units of the currency, or a
/// [problem], or neither when nothing was typed.
typedef AmountRead = ({int? minor, AmountInputProblem? problem});

/// The amount typed in [raw], in [currency]'s minor units, read in the
/// person's format [locale].
AmountRead readAmountInput(
  String raw, {
  required String locale,
  required String currency,
  required bool allowNegative,
}) {
  if (raw.trim().isEmpty) return (minor: null, problem: null);
  final value = parseDecimalInput(
    raw,
    locale: locale,
    threeDecimals: Currencies.minorDigits(currency) >= 3,
  );
  if (value == null) {
    return (minor: null, problem: AmountInputProblem.notANumber);
  }
  if (value < 0 && !allowNegative) {
    return (minor: null, problem: AmountInputProblem.negative);
  }
  final scaled = value * Currencies.minorPerMajor(currency);
  final minor = scaled.round();
  final tolerance = 1e-9 * (scaled.abs() < 1 ? 1 : scaled.abs());
  if ((scaled - minor).abs() > tolerance) {
    return (minor: null, problem: AmountInputProblem.tooManyDecimals);
  }
  return (minor: minor, problem: null);
}

/// [minor] units of [currency] as a field's starting text in the reader's
/// [locale]: its decimal separator, no grouping, at the currency's own
/// precision (`12,50` in de_DE, `12.50` in en_GB, `1500` yen everywhere,
/// `1,250` dinar in de_DE), which [readAmountInput] reads back in the same
/// locale as the same minor units.
String amountInputText(
  int minor, {
  required String currency,
  required String locale,
}) {
  final digits = Currencies.minorDigits(currency);
  final per = Currencies.minorPerMajor(currency);
  final sign = minor < 0 ? '-' : '';
  final whole = minor.abs() ~/ per;
  if (digits == 0) return '$sign$whole';
  final fraction = '${minor.abs() % per}'.padLeft(digits, '0');
  return '$sign$whole${decimalSeparatorOf(locale)}$fraction';
}
