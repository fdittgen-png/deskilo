// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the one place an invoice of the application becomes the
// neutral context an invoice profile renders from. The figures are computed
// ONCE here (the totals rule UBL and CII read as well), so a profile that
// moves into a jurisdiction package neither sees the invoice model nor the tax
// reference, and the renderings of one invoice cannot disagree.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import '../../../../core/i18n/currencies.dart';
import '../../domain/e_invoice_totals.dart';
import '../../domain/einvoice_input.dart';
import '../../domain/invoice.dart';
import '../../domain/stamp_duty.dart';
import '../../domain/vat_regime.dart';

DocumentParty _party(InvoiceParty p) => DocumentParty(
  name: p.name,
  street: p.street,
  city: p.city,
  postalCode: p.postalCode,
  subdivision: p.subdivision,
  country: p.country,
  vatId: p.vatId,
  legalId: p.legalId,
  endpointScheme: p.endpointScheme,
  endpointId: p.endpointId,
);

/// The context of [input]; [transmitterId] and [progressive] are the sender's
/// own routing facts for the channels that want them.
InvoiceDocumentContext invoiceDocumentContextOf(
  EInvoiceInput input, {
  String transmitterId = '',
  String progressive = '',
}) {
  final invoice = input.invoice;
  final totals = eInvoiceTotalsOf(
    invoice: invoice,
    seller: input.seller,
    buyer: input.buyer,
  );
  final sign = invoice.isCreditNote ? -1 : 1;
  final gross =
      sign *
      totals.supplyBreakdown.fold<int>(
        0,
        (n, t) => n + t.netCents + t.vatCents,
      );
  return InvoiceDocumentContext(
    number: invoice.number,
    issuedAt: invoice.issuedAt,
    currency: invoice.currency,
    currencyExponent: Currencies.minorDigits(invoice.currency),
    creditNote: invoice.isCreditNote,
    replacesNumber: invoice.replacesNumber,
    seller: _party(input.seller),
    buyer: _party(input.buyer),
    lines: [
      for (final line in totals.supplies)
        DocumentLine(
          text: input.lineText(line),
          quantity: line.quantity,
          grossMinor: line.amountCents,
          vatPercent: line.vatPercent,
          vatCategory: line.vatCategory,
        ),
    ],
    vatBreakdown: [
      for (final t in totals.supplyBreakdown)
        DocumentVatTotal(
          percent: t.percent,
          category: t.category,
          netMinor: t.netCents,
          vatMinor: t.vatCents,
        ),
    ],
    payableMinor: invoice.totalCents,
    sellerVatRegistered: totals.regime == VatRegime.vatRegistered,
    category: totals.category,
    exemptionText: totals.exemptionText,
    dueDate: input.dueDate,
    iban: input.iban,
    stampDutyMinor: stampDutyCents((
      country: input.seller.country,
      currency: invoice.currency,
      day: invoice.issuedAt,
      totals: totals.supplyBreakdown,
      grossCents: gross,
      buyerCountry: input.buyer.country,
    )),
    transmitterId: transmitterId,
    progressive: progressive,
  );
}
