// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the payment slips this build installs: a static list,
// compiled in, like the other capabilities. A country not listed carries none.
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
