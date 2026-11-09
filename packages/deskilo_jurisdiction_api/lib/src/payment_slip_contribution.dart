// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// A country's payment slip on the invoice (Switzerland's QR bill): the
/// country is the one in the capability id (`payment_slip.CH`). Its existence
/// is the gate -- a seller whose country has no slip is given none -- and this
/// declares what the slip's addresses need to know about the country. Data, not
/// behaviour: the host builds the bill and paints the page.
abstract class PaymentSlipContribution {
  const PaymentSlipContribution();

  CapabilityDescriptor get descriptor;

  /// The country of a payer whose address names none (ISO 3166-1 alpha-2).
  String get debtorDefaultCountry;

  /// What an address of [country] is prefixed with on the slip's page, before
  /// its postal code: '' for the slip's own country (`8000 Zurich`), the
  /// country and a hyphen for another (`DE-10115 Berlin`).
  String addressCountryPrefix(String country);
}
