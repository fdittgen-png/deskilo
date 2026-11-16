// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

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

  /// BT-39 — the region of the space's own address: CIUS-RO wants the
  /// county of a Romanian one, FatturaPA the province of an Italian one.
  sellerSubdivision,

  /// BT-54 — the same for the customer's address (#3649: the reason names
  /// whose region is missing).
  buyerSubdivision,

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
    EInvoiceFormat.ciusRo => _regionGaps('RO', seller, buyer),
    EInvoiceFormat.fatturaPa => [
      if (blank(seller.vatId)) ChannelGap.sellerVatId,
      if (blank(buyer.vatId) && blank(buyer.legalId)) ChannelGap.buyerTaxId,
      ..._regionGaps(seller.country.trim().toUpperCase(), seller, buyer),
    ],
    EInvoiceFormat.ksefFa3 => [if (blank(seller.vatId)) ChannelGap.sellerVatId],
    EInvoiceFormat.facturX || EInvoiceFormat.en16931Ubl => const [],
  };
}

/// #3649 -- a format that needs the region of an address in [country] names
/// whose is missing; nothing is written in its place. FatturaPA is the format
/// of the seller's own country, so it asks the province of an address there.
List<ChannelGap> _regionGaps(
  String country,
  InvoiceParty seller,
  InvoiceParty buyer,
) {
  bool lacks(InvoiceParty p) =>
      country.isNotEmpty &&
      p.country.trim().toUpperCase() == country &&
      p.subdivision.trim().isEmpty;
  return [
    if (lacks(seller)) ChannelGap.sellerSubdivision,
    if (lacks(buyer)) ChannelGap.buyerSubdivision,
  ];
}
