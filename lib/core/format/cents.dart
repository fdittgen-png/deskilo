// SPDX-License-Identifier: 0BSD

// Cent-amount helpers — formerly three identical private `_money` clones
// (billing, services, accessories editors) and two inline amount parsers.

/// Major-unit editor display of [cents]: whole amounts without decimals
/// ('150'), fractional ones with two ('12.50'). NOT a currency rendering —
/// screens showing money to members use `NumberFormat.simpleCurrency`.
String centsToMajor(int cents) =>
    cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

/// Parses a user-typed major-unit amount ('12', '12.5', '12,50') to cents.
/// Empty input reads as 0 (editors treat blank as free); malformed or
/// negative input returns null.
int? parseCentsInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;
  final value = double.tryParse(trimmed.replaceAll(',', '.'));
  if (value == null || value < 0) return null;
  return (value * 100).round();
}
