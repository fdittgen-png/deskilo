// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4418 -- one essential an invoice still lacks, as the server names it
// (stable keys: 0365, 0434, 0792, 9999). Decoded once here; the words and the
// checks switch on it. A key's prefix still says whose fact it is
// (`seller_`, `buyer_`, `vat_`), so a key from a newer server that this app
// does not know is shown as its own text and still counted on the right side.
enum InvoiceMissing {
  invoiceFeatureDisabled('invoice_feature_disabled'),
  sellerAddress('seller_address'),
  sellerVatId('seller_vat_id'),
  exemptionReason('exemption_reason'),
  buyerName('buyer_name'),
  buyerAddress('buyer_address'),
  buyerVatId('buyer_vat_id'),
  sellerCountryUnsupported('seller_country_unsupported'),
  sellerTaxNumber('seller_tax_number'),
  buyerTaxId('buyer_tax_id'),
  vatNationalCurrency('vat_national_currency'),
  sellerVatIdFormat('seller_vat_id_format'),
  sellerUidFormat('seller_uid_format'),
  sellerBnFormat('seller_bn_format'),
  sellerQstNumber('seller_qst_number'),
  correctionReason('correction_reason'),
  vatRateUnresolved('vat_rate_unresolved'),
  vatLineZeroUnexplained('vat_line_zero_unexplained'),
  vatChargedNotRegistered('vat_charged_not_registered'),
  vatTreatmentUnreviewed('vat_treatment_unreviewed'),
  viesUnverified('vies_unverified'),
  buyerCapacityUnknown('buyer_capacity_unknown'),
  salesTaxRateUnset('sales_tax_rate_unset'),
  salesTaxTaxabilityUnset('sales_tax_taxability_unset'),
  territoryOutsideVat('territory_outside_vat'),
  sellerRegion('seller_region'),
  buyerRegion('buyer_region'),

  /// A key a newer server sent and this app does not know (#3730): shown
  /// as its own text.
  unknown('');

  const InvoiceMissing(this.wire);

  /// The key the server sends.
  final String wire;

  /// [raw] as this app reads it; a key it does not know is [unknown].
  static InvoiceMissing fromWire(String? raw) {
    for (final m in values) {
      if (m != unknown && m.wire == raw) return m;
    }
    return unknown;
  }
}
