// SPDX-License-Identifier: 0BSD
import 'invoice.dart';
import 'vat_compliance.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// #1154 — the figures a structured e-invoice states, computed ONCE.
///
/// The CII (Factur-X) and UBL builders opened with the same twenty
/// lines: the tax category, the exemption code and mention, the
/// charges, the VAT breakdown and its sums, the prepaid amount. Two
/// copies of the totals rule is how the two documents of one invoice
/// come to disagree; this is the one place both read.
class EInvoiceTotals {
  const EInvoiceTotals({
    required this.regime,
    required this.category,
    required this.exemptionCode,
    required this.exemptionText,
    required this.charges,
    required this.chargesCents,
    required this.breakdown,
    required this.netCents,
    required this.taxCents,
    required this.prepaidCents,
  });

  final VatRegime regime;

  /// #895 — a reverse-charged document is category AE whatever the
  /// seller's own regime says: the tax is the customer's.
  /// #985 — or the counterparty's category (G, E) when it decided.
  final String category;
  final String exemptionCode;
  final String exemptionText;

  /// The positive positions — what is charged.
  final List<InvoiceLine> charges;
  final int chargesCents;
  final List<InvoiceVatTotal> breakdown;
  final int netCents;
  final int taxCents;

  /// The credits already on the document, as a positive amount.
  final int prepaidCents;
}

EInvoiceTotals eInvoiceTotalsOf({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
}) {
  final regime = vatRegimeFromWire(seller.vatRegime);
  final category = invoice.counterpartyCategory.isNotEmpty
      ? invoice.counterpartyCategory
      : regime.taxCategoryCode;
  final charges =
      invoice.lines.where((l) => l.amountCents > 0).toList(growable: false);
  final breakdown = invoice.vatBreakdown(zeroCategory: category);
  return EInvoiceTotals(
    regime: regime,
    category: category,
    exemptionCode: exemptionCodeForCategory(category, seller.country, regime),
    exemptionText: exemptionMentionFor(
      category: category,
      sellerCountry: seller.country,
      sellerReason: seller.taxExemptionReason,
      buyerReason: buyer.taxExemptionReason,
      regime: regime,
    ),
    charges: charges,
    chargesCents: charges.fold(0, (sum, l) => sum + l.amountCents),
    breakdown: breakdown,
    netCents: breakdown.fold(0, (sum, t) => sum + t.netCents),
    taxCents: breakdown.fold(0, (sum, t) => sum + t.vatCents),
    prepaidCents: -invoice.lines
        .where((l) => l.amountCents < 0)
        .fold(0, (sum, l) => sum + l.amountCents),
  );
}
