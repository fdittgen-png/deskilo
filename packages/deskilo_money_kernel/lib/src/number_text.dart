// SPDX-License-Identifier: AGPL-3.0-or-later

/// A VAT rate as a file states it (#2385): a whole rate without
/// decimals (`20`), a fractional one as written (`5.5`).
///
/// [decimalSeparator] is `,` for the files read in French and German
/// (`5,5`); [fractionDigits] fixes the decimals of a fractional rate
/// (the VAT report states one). Locale-aware rendering for a screen is
/// `NumberFormat`, not this.
String percentText(
  double percent, {
  String decimalSeparator = '.',
  int? fractionDigits,
}) {
  if (percent == percent.roundToDouble()) return percent.toStringAsFixed(0);
  final text = fractionDigits == null
      ? percent.toString()
      : percent.toStringAsFixed(fractionDigits);
  return decimalSeparator == '.'
      ? text
      : text.replaceAll('.', decimalSeparator);
}
