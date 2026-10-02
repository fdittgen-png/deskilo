// SPDX-License-Identifier: AGPL-3.0-or-later
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
    required this.supplies,
    required this.supplyBreakdown,
    required this.moneyCents,
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

  /// #1919 — the lines that are SUPPLIES or their reversals, in document
  /// order: charges (positive) and negative lines that name a VAT rate
  /// (an avoir gives back the VAT of what it cancels, 0156). The UBL
  /// renders exactly these as lines; CII keeps [charges]/[prepaidCents].
  final List<InvoiceLine> supplies;

  /// The VAT breakdown of [supplies] only: the issued breakdown when the
  /// invoice carries one (0156 already counts a rated reversal and never
  /// a 0 % money line), else computed from the supplies.
  final List<InvoiceVatTotal> supplyBreakdown;

  /// Money moving, as a positive amount: negative lines with NO rate —
  /// a payment received or a credit balance applied (#1919: not every
  /// negative line is a payment, but only a rated one reverses a supply).
  final int moneyCents;
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
  final supplies = invoice.lines
      .where((l) => l.amountCents > 0 || (l.amountCents < 0 && l.vatPercent > 0))
      .toList(growable: false);
  final supplyBreakdown = invoice.vatTotals.isNotEmpty
      ? invoice.vatTotals
      : vatTotalsOf([
          for (final line in supplies)
            (amountCents: line.amountCents, vatPercent: line.vatPercent),
        ], zeroCategory: category);
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
    supplies: supplies,
    supplyBreakdown: supplyBreakdown,
    moneyCents: -invoice.lines
        .where((l) => l.amountCents < 0 && l.vatPercent == 0)
        .fold(0, (sum, l) => sum + l.amountCents),
  );
}
