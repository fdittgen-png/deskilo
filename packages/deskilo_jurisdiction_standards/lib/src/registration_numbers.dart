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

/// #2360 — the Swiss UID (Unternehmens-Identifikationsnummer) of a
/// VAT-registered seller: `CHE-123.456.789 MWST` (art. 26 Abs. 2 lit. a
/// MWSTG; `TVA` and `IVA` in French and Italian). The ninth digit checks
/// the first eight (modulus 11, weights 5 4 3 2 7 6 5 4). The server twin
/// is `swiss_uid_valid` (migration 0420).
bool isValidSwissUid(String uid, {bool requireSuffix = true}) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE(\d{9})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null || (requireSuffix && m.group(2) == null)) return false;
  final digits = m.group(1)!.codeUnits.map((c) => c - 48).toList();
  const weights = [5, 4, 3, 2, 7, 6, 5, 4];
  var sum = 0;
  for (var i = 0; i < 8; i++) {
    sum += digits[i] * weights[i];
  }
  final check = 11 - sum % 11;
  return check != 10 && (check == 11 ? 0 : check) == digits[8];
}

/// The UID as it prints: `CHE-123.456.789 MWST`. Anything that is not
/// shaped like a UID is returned as typed.
String formatSwissUid(String uid) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE(\d{3})(\d{3})(\d{3})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null) return uid;
  return 'CHE-${m[1]}.${m[2]}.${m[3]}${m[4] == null ? '' : ' ${m[4]}'}';
}
