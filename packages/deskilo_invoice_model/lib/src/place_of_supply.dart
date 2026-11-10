// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import 'supply_class.dart';
import 'vat_treatment.dart';

/// UNCL5305 category code AE: VAT reverse charge. The one place the code is
/// written; the builders and the exemption texts match on this constant.
const uncl5305ReverseCharge = 'AE';

/// #2354 — the member states, ONE set for the whole app. #2478: the rows of
/// the `eu_member` domain of the tax reference store, no list in code; the
/// SQL `public.is_eu_country` reads the same rows. Greece is `GR` here, as
/// ISO says; `EL` is only its VAT-number prefix, an alias row accepted on
/// input and normalised by [euCountryCode].
/// The member states of [reference].
Set<String> euMemberStatesOf(TaxReferenceSet reference) => reference.euMembers();

/// The canonical code for [code]: trimmed, upper case, an alias row
/// resolved (`EL` → `GR`, `public.eu_country_code`).
String euCountryCode(String code, {required TaxReferenceSet reference}) =>
    reference.euCode(code);

bool isEuCountry(String code, {required TaxReferenceSet reference}) =>
    reference.isEu(code);

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
  required TaxReferenceSet reference,
}) {
  switch (treatment) {
    case VatTreatment.export:
      return 'G';
    case VatTreatment.exempt:
      return 'E';
    case VatTreatment.reverseCharge:
      return uncl5305ReverseCharge;
    case VatTreatment.domestic:
      return '';
    case VatTreatment.auto:
      break;
  }
  if (supply != SupplyClass.general) return '';
  if (!sellerVatRegistered) return '';
  if (!isEuCountry(sellerCountry, reference: reference)) return '';
  if (buyerCapacity != 'business') return '';
  if (buyerCountry.trim().isEmpty) return '';
  if (euCountryCode(buyerCountry, reference: reference) ==
      euCountryCode(sellerCountry, reference: reference)) {
    return '';
  }
  if (isEuCountry(buyerCountry, reference: reference)) {
    return reverseChargeOn ? uncl5305ReverseCharge : '';
  }
  return 'G';
}
