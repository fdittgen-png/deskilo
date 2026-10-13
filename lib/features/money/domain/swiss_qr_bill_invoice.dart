// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the QR-bill of an invoice: where a Swiss seller's customer pays.
import '../../workspace/domain/payment_instructions.dart';
import 'invoice.dart';
import 'swiss_qr_bill.dart';

/// The QR-bill of [invoice], or null where none applies: the seller is not
/// Swiss, the document is a proforma, a credit note or voided, the
/// currency is neither CHF nor EUR, or the workspace has no Swiss account
/// ([instructions]) the guidelines accept. [workspaceCountry] and
/// [workspaceName] stand in for a snapshot without a seller party.
SwissQrBill? swissQrBillOf(
  Invoice invoice, {
  required PaymentInstructions instructions,
  required String workspaceCountry,
  bool proforma = false,
}) {
  final seller = invoice.sellerParty;
  final country = (seller?.country.isNotEmpty ?? false)
      ? seller!.country
      : workspaceCountry;
  if (country.trim().toUpperCase() != 'CH' ||
      proforma ||
      invoice.isVoided ||
      invoice.totalCents <= 0) {
    return null;
  }
  final creditor = SwissQrAddress.fromLines(
    name: seller?.name.isNotEmpty ?? false ? seller!.name : invoice.workspaceName,
    streetLine: seller?.street ?? '',
    postalCode: seller?.postalCode ?? '',
    city: seller?.city ?? '',
  );
  final buyer = invoice.buyerParty;
  final debtor = buyer == null || buyer.postalCode.isEmpty || buyer.city.isEmpty
      ? null
      : SwissQrAddress.fromLines(
          name: buyer.company.isNotEmpty ? buyer.company : buyer.name,
          streetLine: buyer.street,
          postalCode: buyer.postalCode,
          city: buyer.city,
          country: buyer.country.isEmpty ? 'CH' : buyer.country,
        );
  return SwissQrBill.forInvoice(
    iban: instructions.iban,
    qrIban: instructions.qrIban,
    creditor: creditor,
    debtor: debtor,
    totalCents: invoice.totalCents,
    currency: invoice.currency,
    invoiceNumber: invoice.number,
    additionalInfo: invoice.number,
  );
}
