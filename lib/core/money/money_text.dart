// SPDX-License-Identifier: AGPL-3.0-or-later
import '../i18n/currencies.dart';

/// A stored minor-unit amount as the plain decimal a FILE writes
/// (#2385): no symbol, no grouping, the currency's own grain —
/// 1 250 EUR → `12.50`, 1 250 JPY → `1250`, −5 EUR → `-0.05`.
///
/// This is the only way an export renders money; a screen renders it
/// with `formatMinor` (locale-aware), and nothing else divides by a
/// literal 100. Integer arithmetic, so no double rounding can move a
/// cent.
///
/// [decimalSeparator] is `,` for the French and German formats (FEC,
/// DATEV, the VAT report); [absolute] drops the sign for the formats
/// that carry it in a column of their own (DATEV's Soll/Haben).
String minorToText(
  int minor,
  String currency, {
  String decimalSeparator = '.',
  bool absolute = false,
}) {
  final per = Currencies.minorPerMajor(currency);
  final digits = Currencies.minorDigits(currency);
  final sign = minor < 0 && !absolute ? '-' : '';
  final abs = minor.abs();
  if (digits == 0) return '$sign$abs';
  final fraction = (abs % per).toString().padLeft(digits, '0');
  return '$sign${abs ~/ per}$decimalSeparator$fraction';
}
