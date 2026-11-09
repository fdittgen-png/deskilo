// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the one place an invoice of the application becomes the
// neutral context an invoice profile renders from. The figures are computed
// ONCE here (the totals rule UBL and CII read as well), so a profile that
// moves into a jurisdiction package neither sees the invoice model nor the tax
// reference, and the renderings of one invoice cannot disagree.
import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceQueries;

import '../../domain/stamp_duty.dart';

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
  DateTime? correctedIssuedAt,
}) {
  final invoice = input.invoice;
  final totals = eInvoiceTotalsOf(
    invoice: invoice,
    seller: input.seller,
    buyer: input.buyer,
    reference: input.reference,
    rules: input.nationalRules,
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
          netMinor: vatSplit(line.amountCents, line.vatPercent).netCents,
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
    progressive: _progressive(progressive, invoice.number),
    period: invoice.period ?? '',
    correctedIssuedAt: correctedIssuedAt,
    euMemberStates: input.reference.euMembers(),
    euCodeAliases: input.reference.euAliases(),
  );
}

/// The sender's unique id for the file: at most ten basic-latin characters.
/// The invoice number already is unique; a long one is hashed.
String _progressive(String given, String number) {
  final clean = (given.isNotEmpty ? given : number).replaceAll(
    RegExp(r'[^A-Za-z0-9]'),
    '',
  );
  if (clean.isNotEmpty && clean.length <= 10) return clean;
  // The SHA-256 of the number: stable across runs and identical on the
  // web, where integers above 2^53 do not exist.
  return sha256
      .convert(utf8.encode(number))
      .toString()
      .substring(0, 10)
      .toUpperCase();
}
