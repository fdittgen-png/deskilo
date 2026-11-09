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

  /// The slip's own country (ISO 3166-1 alpha-2): the country of the creditor
  /// and of a payer whose address names none.
  String get homeCountry;

  /// The countries whose IBANs the slip accepts as its creditor account (the
  /// Swiss QR bill: Switzerland and Liechtenstein), upper-case ISO codes. A
  /// QR-IBAN is one of these with a QR institution identifier.
  Set<String> get accountCountries;

  /// What an address of [country] is prefixed with on the slip's page, before
  /// its postal code: '' for the slip's own country (`8000 Zurich`), the
  /// country and a hyphen for another (`DE-10115 Berlin`).
  String addressCountryPrefix(String country);
}
