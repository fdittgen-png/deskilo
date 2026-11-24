// SPDX-License-Identifier: AGPL-3.0-or-later

/// Protocol and memory ceilings for the diagnostic terminal profile.
abstract final class EmbeddedTillLimits {
  static const major = 1;
  static const minor = 0;
  static const boardId = 'lcdwiki_e32r40t';
  static const width = 480;
  static const height = 320;
  static const requestBytes = 8192;
  static const responseBytes = 16384;
  static const keysPerPage = 8;
  static const pages = 12;
  static const labelBytes = 96;
  static const unitBytes = 32;
  static const depth = 12;
  static const revisionMax = 2147483647;
  static const minorDigits = {0, 2, 3};
  static const capabilities = {'profile.v1', 'diagnostics'};
  static final minorMin = BigInt.parse('-9223372036854775808');
  static final minorMax = BigInt.parse('9223372036854775807');
  static final quantityScale = BigInt.from(1000000);
}

/// An exact signed-64-bit amount; financial JSON never passes through a double.
BigInt? embeddedMinorOf(String value) {
  if (!RegExp(r'^(0|-[1-9][0-9]*|[1-9][0-9]*)$').hasMatch(value) ||
      value.length > 20)
    return null;
  final parsed = BigInt.tryParse(value);
  return parsed != null &&
          parsed >= EmbeddedTillLimits.minorMin &&
          parsed <= EmbeddedTillLimits.minorMax
      ? parsed
      : null;
}

/// The existing wire quantity grammar, represented exactly as millionths.
BigInt? embeddedQuantityOf(String value) {
  if (!RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = BigInt.parse(parts.first) * EmbeddedTillLimits.quantityScale;
  final fraction = parts.length == 2
      ? BigInt.parse(parts.last.padRight(6, '0'))
      : BigInt.zero;
  return whole + fraction > BigInt.zero ? whole + fraction : null;
}

/// Gross-only arithmetic for contract fixtures; this does not price an online sale.
String? embeddedLineTotal(String unitMinor, String quantity) {
  final amount = embeddedMinorOf(unitMinor);
  final units = embeddedQuantityOf(quantity);
  if (amount == null || amount.isNegative || units == null) return null;
  final scale = EmbeddedTillLimits.quantityScale;
  final total = (amount * units + scale ~/ BigInt.two) ~/ scale;
  return total <= EmbeddedTillLimits.minorMax ? total.toString() : null;
}
