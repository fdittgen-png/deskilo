// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (FIN audit) -- the exemption reason of a VAT rate of category E or O is picked from the invoice model's VATEX
// codes (vatRateExemptionCodes), never typed. What a rate stores is the code's legal wording in the business's
// document language (EN 16931 BT-120), as the setup questionnaire exports it (#4497); a stored wording no code has
// stays as it is until a code is picked.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

/// The codes a rate of [category] may name: none for S and Z.
List<String> vatExemptionCodesOf(String category) => vatRateExemptionCodes[category] ?? const [];

/// Whether a rate of [category] names an exemption reason.
bool vatCategoryNamesExemption(String category) => vatExemptionCodesOf(category).isNotEmpty;

/// The code whose wording, in any of [wordingsOf]'s languages, is [stored]; null for an empty or unknown wording.
String? vatExemptionCodeOfWording(String category, String stored, Iterable<String> Function(String code) wordingsOf) {
  final text = stored.trim();
  if (text.isEmpty) return null;
  for (final code in vatExemptionCodesOf(category)) {
    if (wordingsOf(code).any((w) => w == text)) return code;
  }
  return null;
}

/// The key stem of [code]'s words ('VATEX-EU-79-C' → '79c', 'VATEX-EU-O' → 'O'): `vatex<stem>Label` and
/// `vatex<stem>Text`, the one wording of O being its label.
String vatexArbStem(String code) {
  final s = code.replaceFirst('VATEX-EU-', '').replaceAll('-', '');
  return s.length == 1 ? s : s.toLowerCase();
}
