// SPDX-License-Identifier: 0BSD
import 'invoice.dart';
import 'vat_compliance.dart';
import 'vat_regime.dart';

/// One thing standing between this invoice and a VALID EN 16931 file.
///
/// The norm's fatal rules are named where they apply: a validator would
/// reject the document with exactly these codes, so the app says it first
/// — in its own words, before the file leaves the phone. Exporting an XML
/// that a platform silently rejects is worse than not exporting at all.
enum EInvoiceGap {
  /// The workspace charges VAT but the invoice carries NO breakdown —
  /// either it was issued before VAT management (0072) or no rate was
  /// configured when it was. Declaring a zero tax the seller does owe is
  /// worse than refusing, so this blocks; adding the rates and issuing a
  /// replacement clears it.
  vatNotSupported,

  /// Category `E` or `S` without the seller VAT identifier (BR-E-02 /
  /// BR-S-02).
  missingVatId,

  /// Category `O` without a company registration number — nothing would
  /// identify the seller (BR-CO-26), and BR-O-02 forbids the VAT id.
  missingLegalId,

  /// Category `E` with neither a VATEX code nor a written reason
  /// (BR-E-10).
  missingExemptionReason,

  /// BR-09 — the seller's country.
  missingSellerCountry,

  /// BR-11 — the customer's country.
  missingBuyerCountry,

  /// BR-16 — an invoice has at least one line. A month whose payments
  /// cover everything has only credits, which the norm carries as a
  /// prepaid amount, not as lines: there is no invoice to send.
  noChargeLines,

  /// Not fatal for the norm, but national profiles (XRechnung, Peppol
  /// BIS) require the seller's city…
  missingSellerCity,

  /// …and post code.
  missingSellerPostalCode,

  /// #878 — the customer's VAT id does not have its member state's
  /// shape (a typo an e-invoice platform will bounce). Not blocking:
  /// the id may be right and the table wrong.
  buyerVatIdFormat,
}

extension EInvoiceGapKind on EInvoiceGap {
  /// Whether the export must refuse (as opposed to warn).
  bool get isBlocking => switch (this) {
        EInvoiceGap.missingSellerCity ||
        EInvoiceGap.missingSellerPostalCode ||
        EInvoiceGap.buyerVatIdFormat =>
          false,
        _ => true,
      };

  /// Whether the owner can clear it in the legal-identity screen.
  bool get fixableInSettings => switch (this) {
        EInvoiceGap.missingVatId ||
        EInvoiceGap.missingLegalId ||
        EInvoiceGap.missingExemptionReason ||
        EInvoiceGap.missingSellerCity ||
        EInvoiceGap.missingSellerPostalCode ||
        EInvoiceGap.vatNotSupported =>
          true,
        _ => false,
      };
}

/// What the e-invoice export can honestly claim about [invoice].
class EInvoiceReadiness {
  const EInvoiceReadiness(this.gaps);

  final List<EInvoiceGap> gaps;

  List<EInvoiceGap> get blocking =>
      gaps.where((g) => g.isBlocking).toList(growable: false);

  List<EInvoiceGap> get warnings =>
      gaps.where((g) => !g.isBlocking).toList(growable: false);

  /// No fatal rule is violated — the file can be exported.
  bool get ready => blocking.isEmpty;

  /// Valid AND complete enough for the strict national profiles.
  bool get clean => gaps.isEmpty;
}

/// Pre-flight check of the fatal EN 16931 rules the app can decide
/// locally. [seller] and [buyer] are the invoice's own snapshot (or, for
/// pre-0069 documents, the live workspace identity — the exporter decides
/// that, this only judges what it is handed).
EInvoiceReadiness checkEInvoiceReadiness({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
}) {
  final regime = vatRegimeFromWire(seller.vatRegime);
  final hasExemptionReason = seller.taxExemptionReason.isNotEmpty ||
      regime.exemptionReasonCode(seller.country).isNotEmpty;
  return EInvoiceReadiness([
    // A VAT-charging seller must show tax. With the breakdown present the
    // document is as valid as any other — that is the whole point of 0072.
    if (regime == VatRegime.vatRegistered && invoice.vatCents == 0)
      EInvoiceGap.vatNotSupported,
    if (regime.requiresVatId && seller.vatId.isEmpty)
      EInvoiceGap.missingVatId,
    if (regime.forbidsVatId && seller.legalId.isEmpty)
      EInvoiceGap.missingLegalId,
    if (regime == VatRegime.exempt && !hasExemptionReason)
      EInvoiceGap.missingExemptionReason,
    if (seller.country.isEmpty) EInvoiceGap.missingSellerCountry,
    if (buyer.country.isEmpty) EInvoiceGap.missingBuyerCountry,
    if (buyer.vatId.isNotEmpty && !looksLikeEuVatId(buyer.vatId))
      EInvoiceGap.buyerVatIdFormat,
    if (!invoice.lines.any((l) => l.amountCents > 0))
      EInvoiceGap.noChargeLines,
    if (seller.city.isEmpty) EInvoiceGap.missingSellerCity,
    if (seller.postalCode.isEmpty) EInvoiceGap.missingSellerPostalCode,
  ]);
}
