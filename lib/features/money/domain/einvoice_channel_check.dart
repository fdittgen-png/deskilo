// SPDX-License-Identifier: AGPL-3.0-or-later
import 'einvoice_format.dart';
import 'invoice.dart';

/// #2358 — one thing a CHANNEL needs that the bare EN 16931 file does
/// not: the download stays valid without it, but the network refuses the
/// document. Judged per format, before the Send button is offered — the
/// official validators (CI · E-invoice validators) reject a document
/// missing any of these.
enum ChannelGap {
  /// BT-34 — Peppol and XRechnung route by it; the French CIUS requires
  /// it (BR-FR-13).
  sellerEndpoint,

  /// BT-49 — the same for the customer (BR-FR-12).
  buyerEndpoint,

  /// BT-10 or BT-13 — Peppol wants one of them (PEPPOL-EN16931-R003).
  buyerReference,

  /// BT-10 — a German public buyer's Leitweg-ID (BR-DE-15).
  leitwegId,

  /// BG-16 — XRechnung wants the payment instructions (BR-DE-1).
  paymentAccount,

  /// BG-6 — XRechnung wants the seller's contact e-mail and telephone
  /// (BR-DE-6/7).
  sellerContact,

  /// BT-39 / BT-54 — CIUS-RO wants the county of a Romanian address.
  subdivision,

  /// FatturaPA and FA(3) identify the seller by its VAT number only.
  sellerVatId,

  /// FatturaPA needs the customer's VAT number or fiscal code.
  buyerTaxId,
}

/// What [format] still needs from [seller], [buyer] and the workspace's
/// [iban]. Empty = the channel has everything its validator checks.
List<ChannelGap> channelGaps(
  EInvoiceFormat format, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  String iban = '',
}) {
  bool blank(String s) => s.trim().isEmpty;
  bool romanian(InvoiceParty p) => p.country.trim().toUpperCase() == 'RO';
  return switch (format) {
    EInvoiceFormat.peppolBis => [
      if (blank(seller.endpointId)) ChannelGap.sellerEndpoint,
      if (blank(buyer.endpointId)) ChannelGap.buyerEndpoint,
      if (blank(buyer.reference) && blank(buyer.orderReference))
        ChannelGap.buyerReference,
    ],
    EInvoiceFormat.xrechnung => [
      if (blank(seller.endpointId)) ChannelGap.sellerEndpoint,
      if (blank(buyer.endpointId)) ChannelGap.buyerEndpoint,
      if (blank(buyer.reference)) ChannelGap.leitwegId,
      if (blank(iban)) ChannelGap.paymentAccount,
      if (blank(seller.email) || blank(seller.phone)) ChannelGap.sellerContact,
    ],
    EInvoiceFormat.en16931Cii => [
      if (blank(seller.endpointId)) ChannelGap.sellerEndpoint,
      if (blank(buyer.endpointId)) ChannelGap.buyerEndpoint,
    ],
    EInvoiceFormat.ciusRo => [
      if ((romanian(seller) && blank(seller.subdivision)) ||
          (romanian(buyer) && blank(buyer.subdivision)))
        ChannelGap.subdivision,
    ],
    EInvoiceFormat.fatturaPa => [
      if (blank(seller.vatId)) ChannelGap.sellerVatId,
      if (blank(buyer.vatId) && blank(buyer.legalId)) ChannelGap.buyerTaxId,
    ],
    EInvoiceFormat.ksefFa3 => [if (blank(seller.vatId)) ChannelGap.sellerVatId],
    EInvoiceFormat.facturX || EInvoiceFormat.en16931Ubl => const [],
  };
}
