// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the payment slips this build installs: a static list,
// compiled in, like the other capabilities. A country not listed carries none.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    show PaymentReferenceRules;
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:meta/meta.dart';

import 'jurisdiction_resolver.dart';
/// Every installed payment slip add-on.
@visibleForTesting
const List<PaymentSlipContribution> installedPaymentSlips = [ChPaymentSlip()];

/// The slip of [country]'s invoices, or null when it has none.
PaymentSlipContribution? paymentSlipOf(String country) => resolvePaymentSlip(
  LegalContext(countryCode: country),
  installedPaymentSlips,
);

/// #3429 -- the IBAN countries every installed slip accepts, for the payment
/// references of e-invoices (a QR-IBAN is judged by the account, not by the
/// seller's country). From the installed add-ons, never a literal.
PaymentReferenceRules get installedPaymentReferenceRules =>
    PaymentReferenceRules(
      accountCountries: {
        for (final slip in installedPaymentSlips) ...slip.accountCountries,
      },
    );

/// The same rules from one slip.
PaymentReferenceRules paymentReferenceRulesOf(PaymentSlipContribution slip) =>
    PaymentReferenceRules(accountCountries: slip.accountCountries);
