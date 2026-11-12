// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:intl/intl.dart';

/// The most decimals a displayed rate keeps (`9.975`: three; a fourth
/// would only print float dust).
const int _maxRateDecimals = 4;

/// A rate already in percent (`20` is 20 %, `8.1` is 8.1 %) as a person
/// reads it in [locale]: the locale's own percent pattern (`5,5 %` in
/// fr_FR, `8.1%` in en_GB), a whole rate without decimals, a fractional
/// one with its own precision (up to four decimals).
String ratePercentText(num percent, {required String? locale}) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = _decimalsOf(percent.toDouble());
  return format.format(percent / 100);
}

/// A fraction (`0.081` is 8.1 %) as a percentage in [locale]; the unit is
/// converted once here, the precision is the rate's own.
String fractionPercentText(num fraction, {required String? locale}) =>
    ratePercentText(
      num.parse((fraction * 100).toStringAsFixed(_maxRateDecimals)),
      locale: locale,
    );

int _decimalsOf(double percent) {
  final text = percent.toStringAsFixed(_maxRateDecimals);
  final fraction = text.split('.').last.replaceFirst(RegExp(r'0+$'), '');
  return fraction.length;
}
