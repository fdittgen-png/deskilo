// SPDX-License-Identifier: AGPL-3.0-or-later
import 'supply_class.dart';
import 'vat_treatment.dart';

/// #2354 — the 27 member states, ONE set for the whole app and the
/// twin of `public.is_eu_country` (pinned by `place_of_supply_test`).
/// Greece is `GR` here, as ISO says; `EL` is only its VAT-number prefix,
/// accepted on input and normalised by [euCountryCode].
const Set<String> euMemberStates = {
  'AT',
  'BE',
  'BG',
  'CY',
  'CZ',
  'DE',
  'DK',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'HU',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MT',
  'NL',
  'PL',
  'PT',
  'RO',
  'SE',
  'SI',
  'SK',
};

/// The canonical code for [code]: trimmed, upper case, `EL` → `GR`
/// (`public.eu_country_code`).
String euCountryCode(String code) {
  final c = code.trim().toUpperCase();
  return c == 'EL' ? 'GR' : c;
}

bool isEuCountry(String code) => euMemberStates.contains(euCountryCode(code));

/// #2354 — the VAT category a line takes from WHERE it is supplied, the
/// twin of `public.supply_vat_category` (pinned case by case against
/// the pgTAP file by `place_of_supply_test`). '' means the seller's own
/// regime decides (domestic VAT: S at a rate, else its zero category).
///
/// A desk, an office or a room is a service connected with immovable
/// property: taxed where the building stands, for every customer
/// (Directive 2006/112/EC art. 47; Reg. 282/2011 art. 31a). Only a
/// [SupplyClass.general] line follows the customer: AE for a business in
/// another member state (art. 44/196), G for a business outside the EU
/// (art. 44). A consumer, wherever they live, pays the seller's VAT on a
/// general service too (art. 45). The capacity is the STATED one
/// (`members.customer_capacity`, else the workspace default) — never
/// inferred from a VAT number. An explicit [VatTreatment] other than
/// automatic decides every line, as the owner chose it.
String supplyVatCategory({
  required VatTreatment treatment,
  required SupplyClass supply,
  required bool sellerVatRegistered,
  required String sellerCountry,
  required String buyerCountry,
  required String buyerCapacity,
  bool reverseChargeOn = true,
}) {
  switch (treatment) {
    case VatTreatment.export:
      return 'G';
    case VatTreatment.exempt:
      return 'E';
    case VatTreatment.reverseCharge:
      return 'AE';
    case VatTreatment.domestic:
      return '';
    case VatTreatment.auto:
      break;
  }
  if (supply != SupplyClass.general) return '';
  if (!sellerVatRegistered) return '';
  if (!isEuCountry(sellerCountry)) return '';
  if (buyerCapacity != 'business') return '';
  if (buyerCountry.trim().isEmpty) return '';
  if (euCountryCode(buyerCountry) == euCountryCode(sellerCountry)) return '';
  if (isEuCountry(buyerCountry)) return reverseChargeOn ? 'AE' : '';
  return 'G';
}
