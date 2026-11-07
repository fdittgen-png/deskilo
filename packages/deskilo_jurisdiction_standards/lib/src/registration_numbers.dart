// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tax registration numbers the filing files check and print, written once for
// every country package (#3333); `lib/features/money/domain/vat_compliance.dart`
// re-exports them.

/// #2361 — the business number of a GST/HST registrant with its RT account:
/// `123456789 RT0001` (ETA s. 169(4); Input Tax Credit Information
/// Regulations). The server twin is the pattern in
/// `invoice_essentials_missing` (migration 0424).
bool isValidCanadianBn(String bn) => RegExp(
  r'^\d{9}RT\d{4}$',
).hasMatch(bn.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''));

/// #2361 — Revenu Québec's QST registration number: `1234567890 TQ0001`.
bool isValidQstNumber(String number) => RegExp(
  r'^\d{10}TQ\d{4}$',
).hasMatch(number.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''));

/// A Canadian registration number as it prints: `123456789 RT0001`,
/// `1234567890 TQ0001`. Anything else is returned as typed.
String formatCanadianRegistration(String number) {
  final id = number.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^(\d{9}|\d{10})(RT|TQ)(\d{4})$').firstMatch(id);
  if (m == null) return number;
  return '${m[1]} ${m[2]}${m[3]}';
}
