// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the national decisions of an e-invoice, asked of the
// installed invoice mentions add-ons: which countries ask the buyer's legal id
// between two of their own businesses, and the VATEX code a seller names for
// an exemption. From the add-ons, never a literal here.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import 'installed_invoice_mentions.dart';
import 'installed_payment_slips.dart';

/// The rules of every installed invoice mentions add-on.
NationalInvoiceRules get installedNationalInvoiceRules => NationalInvoiceRules(
  domesticBuyerLegalIdCountries: {
    for (final c in installedInvoiceMentions)
      if (c.requiresDomesticBuyerLegalId) c.descriptor.country,
  },
  exemptionReasonCodes: {
    for (final c in installedInvoiceMentions)
      if (c.exemptionReasonCode.isNotEmpty)
        c.descriptor.country: c.exemptionReasonCode,
  },
);

/// The account a document names with the rules it is judged by (the payment
/// reference countries of the installed slips and the national rules above).
InvoiceAccount installedInvoiceAccount({String iban = ''}) => InvoiceAccount(
  payment: PaymentAccount(rules: installedPaymentReferenceRules, iban: iban),
  national: installedNationalInvoiceRules,
);
