// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the QR-bill of an invoice: where a Swiss seller's customer pays.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart'
    show PaymentSlipContribution;

import '../../../core/jurisdiction/installed_payment_slips.dart';
/// #3429 -- the payment slip of the country [invoice]'s seller sells from (the
/// seller party's, else [workspaceCountry]), from the installed add-on; null
/// where that country has none.
PaymentSlipContribution? paymentSlipFor(
  Invoice invoice,
  String workspaceCountry,
) {
  final seller = invoice.sellerParty;
  return paymentSlipOf(
    (seller?.country.isNotEmpty ?? false) ? seller!.country : workspaceCountry,
  );
}

/// The QR-bill of [invoice], or null where none applies: the seller is not
/// Swiss, the document is a proforma, a credit note or voided, the
/// currency is neither CHF nor EUR, or the workspace has no Swiss account
/// ([iban], [qrIban]) the guidelines accept. [workspaceCountry] and
/// [workspaceName] stand in for a snapshot without a seller party.
SwissQrBill? swissQrBillOf(
  Invoice invoice, {
  required String iban,
  required String qrIban,
  required String workspaceCountry,
  bool proforma = false,
}) {
  final seller = invoice.sellerParty;
  // the seller's country has a payment slip, or the invoice carries none
  final slip = paymentSlipFor(invoice, workspaceCountry);
  if (slip == null ||
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
    country: slip.homeCountry,
  );
  final buyer = invoice.buyerParty;
  final debtor = buyer == null || buyer.postalCode.isEmpty || buyer.city.isEmpty
      ? null
      : SwissQrAddress.fromLines(
          name: buyer.company.isNotEmpty ? buyer.company : buyer.name,
          streetLine: buyer.street,
          postalCode: buyer.postalCode,
          city: buyer.city,
          country: buyer.country.isEmpty ? slip.homeCountry : buyer.country,
        );
  return SwissQrBill.forInvoice(
    account: PaymentAccount(
      iban: iban,
      qrIban: qrIban,
      rules: paymentReferenceRulesOf(slip),
    ),
    creditor: creditor,
    debtor: debtor,
    totalCents: invoice.totalCents,
    currency: invoice.currency,
    invoiceNumber: invoice.number,
    additionalInfo: invoice.number,
    frozenQrr: invoiceQrrOf(invoice.number, invoice.legalSnapshot),
  );
}
